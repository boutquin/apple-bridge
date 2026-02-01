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
                    set pName to name of thePerson
                    set pId to id of thePerson
                    set pEmail to ""
                    if (count of emails of thePerson) > 0 then
                        set pEmail to value of first email of thePerson
                    end if
                    set pPhone to ""
                    if (count of phones of thePerson) > 0 then
                        set pPhone to value of first phone of thePerson
                    end if
                    return pId & "\\t" & pName & "\\t" & pEmail & "\\t" & pPhone
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
                    set myCard to my card
                    set pName to name of myCard
                    set pId to id of myCard
                    set pEmail to ""
                    if (count of emails of myCard) > 0 then
                        set pEmail to value of first email of myCard
                    end if
                    set pPhone to ""
                    if (count of phones of myCard) > 0 then
                        set pPhone to value of first phone of myCard
                    end if
                    return pId & "\\t" & pName & "\\t" & pEmail & "\\t" & pPhone
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
                set pName to name of thePerson
                set pId to id of thePerson
                set pEmail to ""
                if (count of emails of thePerson) > 0 then
                    set pEmail to value of first email of thePerson
                end if
                set pPhone to ""
                if (count of phones of thePerson) > 0 then
                    set pPhone to value of first phone of thePerson
                end if
                set end of resultList to pId & "\\t" & pName & "\\t" & pEmail & "\\t" & pPhone & "\\n"
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
                    set pName to name of thePerson
                    set pId to id of thePerson
                    set pEmail to ""
                    if (count of emails of thePerson) > 0 then
                        set pEmail to value of first email of thePerson
                    end if
                    set pPhone to ""
                    if (count of phones of thePerson) > 0 then
                        set pPhone to value of first phone of thePerson
                    end if
                    set end of resultList to pId & "\\t" & pName & "\\t" & pEmail & "\\t" & pPhone & "\\n"
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

    /// Parses tab-delimited contact response into `ContactData` array.
    private func parseContactResponse(_ response: String) -> [ContactData] {
        let lines = response.components(separatedBy: "\n").filter { !$0.isEmpty }

        return lines.compactMap { line -> ContactData? in
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { return nil }

            let id = parts[0]
            let displayName = parts[1]
            let email = parts.count > 2 && !parts[2].isEmpty ? parts[2] : nil
            let phone = parts.count > 3 && !parts[3].isEmpty ? parts[3] : nil

            return ContactData(
                id: id,
                displayName: displayName,
                email: email,
                phone: phone
            )
        }
    }
}
