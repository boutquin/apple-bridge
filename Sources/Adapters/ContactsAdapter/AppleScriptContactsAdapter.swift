import Foundation
import Core

/// AppleScript implementation of `ContactsAdapterProtocol`.
///
/// Uses `osascript` to communicate with the Contacts app instead of
/// `CNContactStore`. This bypasses the TCC permission issue where ad-hoc
/// signed CLI tools cannot obtain Contacts framework authorization.
/// AppleScript uses the Automation TCC pathway, which works reliably
/// for command-line tools.
public struct AppleScriptContactsAdapter: ContactsAdapterProtocol, Sendable {

    private let runner: any AppleScriptRunnerProtocol

    // MARK: - Initialization

    /// Creates a new adapter using the shared AppleScript runner.
    public init() {
        self.runner = AppleScriptRunner.shared
    }

    /// Creates a new adapter with a custom runner (for testing).
    public init(runner: any AppleScriptRunnerProtocol) {
        self.runner = runner
    }

    // MARK: - Authorization

    public func requestAccess() async throws -> Bool {
        // AppleScript handles its own permission via Automation TCC.
        // A simple probe tells us whether we have access.
        let script = """
            tell application "Contacts"
                count of people
            end tell
            """
        do {
            _ = try await runner.run(script: script, timeout: 10)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Contact Operations

    public func fetchContacts(query: String, limit: Int) async throws -> [ContactData] {
        let script: String
        if query.isEmpty {
            script = buildFetchAllScript(limit: limit)
        } else {
            script = buildSearchScript(query: query, limit: limit)
        }

        let result = try await runner.run(script: script, timeout: 15)
        return parseContactResponse(result)
    }

    public func fetchContact(id: String) async throws -> ContactData {
        let escapedId = escapeForAppleScript(id)
        let script = """
            tell application "Contacts"
                try
                    set thePerson to first person whose id is "\(escapedId)"
            \(Self.projectPersonScript)
                    return personRecord
                on error
                    error "CONTACT_NOT_FOUND"
                end try
            end tell
            """

        let result: String
        do {
            result = try await runner.run(script: script, timeout: 10)
        } catch let error as AppleScriptError {
            if case .executionFailed(let message) = error,
               message.contains("CONTACT_NOT_FOUND") {
                throw ValidationError.notFound(resource: "contact", id: id)
            }
            throw error
        }

        let contacts = parseContactResponse(result)
        guard let contact = contacts.first else {
            throw ValidationError.notFound(resource: "contact", id: id)
        }
        return contact
    }

    public func fetchMeContact() async throws -> ContactData? {
        let script = """
            tell application "Contacts"
                try
                    set thePerson to my card
            \(Self.projectPersonScript)
                    return personRecord
                on error
                    return ""
                end try
            end tell
            """

        let result = try await runner.run(script: script, timeout: 10)
        if result.isEmpty { return nil }

        let contacts = parseContactResponse(result)
        return contacts.first
    }

    public func openContact(id: String) async throws {
        let escapedId = escapeForAppleScript(id)
        let script = """
            tell application "Contacts"
                try
                    set thePerson to first person whose id is "\(escapedId)"
                    activate
                on error
                    error "CONTACT_NOT_FOUND"
                end try
            end tell
            """

        do {
            _ = try await runner.run(script: script, timeout: 10)
        } catch let error as AppleScriptError {
            if case .executionFailed(let message) = error,
               message.contains("CONTACT_NOT_FOUND") {
                throw ValidationError.notFound(resource: "contact", id: id)
            }
            throw error
        }
    }

    // MARK: - Write Operations

    public func createContact(_ data: ContactData) async throws -> ContactData {
        // Checked against the NAME fields specifically, not "any property":
        // an organization alone would otherwise satisfy a non-empty check and
        // create a nameless contact, which is exactly what create forbids and
        // what this adapter's doc-comment promises to reject. The handler
        // enforces the same rule; this is the layer that makes the promise true
        // for any other caller.
        guard data.givenName?.isEmpty == false
                || data.familyName?.isEmpty == false
                || !data.displayName.isEmpty else {
            throw ValidationError.missingRequired(field: "givenName, familyName, or displayName")
        }
        let properties = Self.personProperties(from: data, includeNameFallback: true)

        // One `save` for the person and every sub-item: a failure before it
        // commits nothing, so a half-written contact is not reachable. The
        // rollback below is belt-and-braces for a failure during the save
        // itself.
        let script = """
            tell application "Contacts"
                set newPerson to make new person with properties {\(properties.joined(separator: ", "))}
                try
            \(Self.makeSubItems(from: data, personVar: "newPerson"))
                    save
                on error errMsg
                    try
                        delete newPerson
                        save
                    end try
                    error "CONTACT_CREATE_FAILED: " & errMsg
                end try
                return id of newPerson
            end tell
            """

        let newId: String
        do {
            newId = try await runner.run(script: script, timeout: 20)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as AppleScriptError {
            if case .executionFailed(let message) = error, message.contains("CONTACT_CREATE_FAILED") {
                throw ValidationError.invalidFormat(field: "contact", expected: "a writable contact: \(message)")
            }
            throw error
        }

        guard !newId.isEmpty else {
            throw ValidationError.invalidFormat(field: "contact", expected: "a store-assigned identifier")
        }
        return try await fetchContact(id: newId)
    }

    public func updateContact(id: String, _ data: ContactData) async throws -> ContactData {
        let escapedId = escapeForAppleScript(id)
        var mutations: [String] = []

        // Absent stays absent: only a non-nil field produces a mutation line.
        func setScalar(_ appleScriptName: String, _ value: String?) {
            guard let value else { return }
            mutations.append("        set \(appleScriptName) of thePerson to \"\(escapeForAppleScript(value))\"")
        }
        setScalar("first name", data.givenName)
        setScalar("last name", data.familyName)
        setScalar("organization", data.organization)
        setScalar("job title", data.jobTitle)
        setScalar("note", data.note)

        // A supplied collection replaces the existing one; `[]` therefore clears.
        func setMulti(_ element: String, _ plural: String, _ entries: [LabeledValue]?) {
            guard let entries else { return }
            mutations.append("        delete every \(element) of thePerson")
            for entry in entries {
                mutations.append("        " + Self.makeSubItem(element: element, plural: plural, entry: entry, personVar: "thePerson"))
            }
        }
        setMulti("email", "emails", data.emails)
        setMulti("phone", "phones", data.phones)
        setMulti("url", "urls", data.urls)

        guard !mutations.isEmpty else { return try await fetchContact(id: id) }

        let script = """
            tell application "Contacts"
                try
                    set thePerson to first person whose id is "\(escapedId)"
                on error
                    error "CONTACT_NOT_FOUND"
                end try
            \(mutations.joined(separator: "\n"))
                save
            end tell
            """

        do {
            _ = try await runner.run(script: script, timeout: 20)
        } catch let error as AppleScriptError {
            if case .executionFailed(let message) = error, message.contains("CONTACT_NOT_FOUND") {
                throw ValidationError.notFound(resource: "contact", id: id)
            }
            throw error
        }

        return try await fetchContact(id: id)
    }

    // MARK: - Write Script Building

    /// Builds the `with properties {…}` body for `make new person`.
    ///
    /// Every value goes through ``escapeForAppleScript(_:)`` — a note carrying a
    /// double quote or a backslash must not terminate the string or inject
    /// script.
    static func personProperties(from data: ContactData, includeNameFallback: Bool) -> [String] {
        var properties: [String] = []
        func add(_ key: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            properties.append("\(key):\"\(escapeStatic(value))\"")
        }
        add("first name", data.givenName)
        add("last name", data.familyName)
        add("organization", data.organization)
        add("job title", data.jobTitle)
        add("note", data.note)

        // Contacts derives `name` from the name parts, so it cannot be set
        // directly. A caller who supplied only a display name gets it as the
        // first name, which is what the Contacts UI does for a mononym.
        if includeNameFallback, data.givenName == nil, data.familyName == nil,
           !data.displayName.isEmpty {
            properties.insert("first name:\"\(escapeStatic(data.displayName))\"", at: 0)
        }
        return properties
    }

    /// One `make new <element> at end of <plural> of <person>` statement.
    static func makeSubItem(element: String, plural: String, entry: LabeledValue, personVar: String) -> String {
        var properties = ["value:\"\(escapeStatic(entry.value))\""]
        if let label = entry.label, !label.isEmpty {
            properties.append("label:\"\(escapeStatic(label))\"")
        }
        return "make new \(element) at end of \(plural) of \(personVar) with properties {\(properties.joined(separator: ", "))}"
    }

    /// All sub-item statements for a new contact, indented for the script body.
    static func makeSubItems(from data: ContactData, personVar: String) -> String {
        var lines: [String] = []
        for entry in data.emails ?? [] {
            lines.append("        " + makeSubItem(element: "email", plural: "emails", entry: entry, personVar: personVar))
        }
        for entry in data.phones ?? [] {
            lines.append("        " + makeSubItem(element: "phone", plural: "phones", entry: entry, personVar: personVar))
        }
        for entry in data.urls ?? [] {
            lines.append("        " + makeSubItem(element: "url", plural: "urls", entry: entry, personVar: personVar))
        }
        return lines.joined(separator: "\n")
    }

    /// Static twin of ``escapeForAppleScript(_:)`` for the type-level builders.
    static func escapeStatic(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Wire Format

    /// Field separator (ASCII US). Separates the fields of one person record.
    private static let fieldSep = "\u{1F}"
    /// Record separator (ASCII RS). Separates person records.
    private static let recordSep = "\u{1E}"
    /// Group separator (ASCII GS). Separates entries within a multi-value field.
    private static let groupSep = "\u{1D}"
    /// Label separator (ASCII FS). Separates an entry's label from its value.
    private static let labelSep = "\u{1C}"

    /// AppleScript that projects the person in `thePerson` into one wire record.
    ///
    /// Control characters are used as delimiters rather than tab and newline
    /// because a contact note is free-form multi-paragraph text: it routinely
    /// contains both, and the pre-3.1.0 tab/newline
    /// format could not carry one without corrupting the record. ASCII 28–31 are
    /// the separators this exists for and do not occur in contact data.
    ///
    /// Leaves the encoded record in `personRecord`.
    private static let projectPersonScript = """
                set fsep to (character id 31)
                set gsep to (character id 29)
                set lsep to (character id 28)
                set pId to id of thePerson
                set pName to name of thePerson
                set pGiven to first name of thePerson
                if pGiven is missing value then set pGiven to ""
                set pFamily to last name of thePerson
                if pFamily is missing value then set pFamily to ""
                set pOrg to organization of thePerson
                if pOrg is missing value then set pOrg to ""
                set pTitle to job title of thePerson
                if pTitle is missing value then set pTitle to ""
                set pNote to note of thePerson
                if pNote is missing value then set pNote to ""
                set pEmails to ""
                set eList to emails of thePerson
                repeat with ei from 1 to (count of eList)
                    set anEntry to item ei of eList
                    set aLabel to label of anEntry
                    if aLabel is missing value then set aLabel to ""
                    set aValue to value of anEntry
                    if aValue is missing value then set aValue to ""
                    if ei > 1 then set pEmails to pEmails & gsep
                    set pEmails to pEmails & aLabel & lsep & aValue
                end repeat
                set pPhones to ""
                set hList to phones of thePerson
                repeat with hi from 1 to (count of hList)
                    set anEntry to item hi of hList
                    set aLabel to label of anEntry
                    if aLabel is missing value then set aLabel to ""
                    set aValue to value of anEntry
                    if aValue is missing value then set aValue to ""
                    if hi > 1 then set pPhones to pPhones & gsep
                    set pPhones to pPhones & aLabel & lsep & aValue
                end repeat
                set pUrls to ""
                set uList to urls of thePerson
                repeat with ui from 1 to (count of uList)
                    set anEntry to item ui of uList
                    set aLabel to label of anEntry
                    if aLabel is missing value then set aLabel to ""
                    set aValue to value of anEntry
                    if aValue is missing value then set aValue to ""
                    if ui > 1 then set pUrls to pUrls & gsep
                    set pUrls to pUrls & aLabel & lsep & aValue
                end repeat
                set personRecord to pId & fsep & pName & fsep & pGiven & fsep & pFamily & fsep & pOrg & fsep & pTitle & fsep & pNote & fsep & pEmails & fsep & pPhones & fsep & pUrls
"""

    // MARK: - Private Helpers

    private func buildFetchAllScript(limit: Int) -> String {
        """
        tell application "Contacts"
            set resultList to {}
            set allPeople to every person
            set pCount to count of allPeople
            if pCount > \(limit) then set pCount to \(limit)
            repeat with i from 1 to pCount
                set thePerson to item i of allPeople
        \(Self.projectPersonScript)
                set end of resultList to personRecord & (character id 30)
            end repeat
            return resultList as string
        end tell
        """
    }

    private func buildSearchScript(query: String, limit: Int) -> String {
        let escapedQuery = escapeForAppleScript(query)
        return """
            tell application "Contacts"
                set resultList to {}
                set matchedPeople to (every person whose name contains "\(escapedQuery)")
                set pCount to count of matchedPeople
                if pCount > \(limit) then set pCount to \(limit)
                repeat with i from 1 to pCount
                    set thePerson to item i of matchedPeople
            \(Self.projectPersonScript)
                    set end of resultList to personRecord & (character id 30)
                end repeat
                return resultList as string
            end tell
            """
    }

    /// Escapes a string for safe use inside AppleScript double-quoted strings.
    private func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Decodes one multi-value field — `label FS value` entries joined by GS.
    ///
    /// Returns an empty array for an empty field: the projection ran and found
    /// nothing, which callers must be able to tell apart from "not projected"
    /// (`nil`). An entry with an empty label decodes to `label: nil`.
    private func parseMultiValue(_ field: String) -> [LabeledValue] {
        guard !field.isEmpty else { return [] }
        return field.components(separatedBy: Self.groupSep).compactMap { entry in
            let parts = entry.components(separatedBy: Self.labelSep)
            guard parts.count == 2 else { return nil }
            let value = parts[1]
            guard !value.isEmpty else { return nil }
            return LabeledValue(label: Self.normalizeLabel(parts[0]), value: value)
        }
    }

    /// Unwraps Apple's internal label encoding.
    ///
    /// The Contacts scripting dictionary returns labels in their raw form —
    /// `_$!<Home>!$_`, `_$!<Work>!$_`, `_$!<HomePage>!$_` — which is an
    /// implementation detail no MCP caller should have to know about. The
    /// `CNContactStore` adapter runs its labels through
    /// `CNLabeledValue.localizedString(forLabel:)` and yields `"home"` / `"work"`,
    /// so without this the two conformances would disagree about what a label
    /// looks like for the same contact. Custom labels are returned unchanged.
    static func normalizeLabel(_ raw: String) -> String? {
        guard !raw.isEmpty else { return nil }
        guard raw.hasPrefix("_$!<"), raw.hasSuffix(">!$_") else { return raw }
        let inner = raw.dropFirst(4).dropLast(4)
        return inner.isEmpty ? nil : inner.lowercased()
    }

    /// Parses the control-character-delimited contact response.
    ///
    /// Records are RS-separated and fields US-separated, so a note containing
    /// tabs or newlines round-trips intact — see ``projectPersonScript`` for why
    /// the format is not tab/newline based.
    private func parseContactResponse(_ response: String) -> [ContactData] {
        let records = response
            .components(separatedBy: Self.recordSep)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return records.compactMap { record -> ContactData? in
            let parts = record.components(separatedBy: Self.fieldSep)
            guard parts.count >= 2 else { return nil }

            func field(_ index: Int) -> String? {
                guard parts.count > index, !parts[index].isEmpty else { return nil }
                return parts[index]
            }

            return ContactData(
                id: parts[0],
                displayName: parts[1],
                givenName: field(2),
                familyName: field(3),
                organization: field(4),
                jobTitle: field(5),
                note: field(6),
                emails: parts.count > 7 ? parseMultiValue(parts[7]) : nil,
                phones: parts.count > 8 ? parseMultiValue(parts[8]) : nil,
                urls: parts.count > 9 ? parseMultiValue(parts[9]) : nil
            )
        }
    }
}
