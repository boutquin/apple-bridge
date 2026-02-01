import Foundation
import Core

/// AppleScript implementation of `NotesAdapterProtocol`.
///
/// Uses `osascript` to communicate with Notes.app instead of reading the
/// SQLite database directly. This bypasses the Full Disk Access TCC
/// requirement, which does not persist for ad-hoc signed CLI tools.
/// AppleScript uses the Automation TCC pathway, which works reliably
/// for command-line tools.
public struct AppleScriptNotesAdapter: NotesAdapterProtocol, Sendable {

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

    // MARK: - NotesAdapterProtocol

    public func searchNotes(query: String, limit: Int, includeBody: Bool) async throws -> [NoteData] {
        let script: String
        if query.isEmpty {
            script = buildFetchAllScript(limit: limit, includeBody: includeBody)
        } else {
            script = buildSearchScript(query: query, limit: limit, includeBody: includeBody)
        }

        let result = try await runner.run(script: script, timeout: 30)
        return parseNoteResponse(result, includeBody: includeBody)
    }

    public func fetchNote(id: String) async throws -> NoteData {
        let escapedId = escapeForAppleScript(id)
        let script = """
            tell application "Notes"
                try
                    set theNote to first note of default account whose id is "\(escapedId)"
                    set nId to id of theNote
                    set nName to name of theNote
                    set nBody to body of theNote
                    set nModDate to modification date of theNote
                    return nId & "\\t" & nName & "\\t" & (nModDate as string) & "\\t" & nBody
                on error
                    error "NOTE_NOT_FOUND"
                end try
            end tell
            """

        let result: String
        do {
            result = try await runner.run(script: script, timeout: 15)
        } catch let error as AppleScriptError {
            if case .executionFailed(let message) = error,
               message.contains("NOTE_NOT_FOUND") {
                throw ValidationError.notFound(resource: "note", id: id)
            }
            throw error
        }

        guard let note = parseSingleNote(result) else {
            throw ValidationError.notFound(resource: "note", id: id)
        }
        return note
    }

    public func createNote(title: String, body: String?, folderId: String?) async throws -> String {
        let escapedTitle = escapeForAppleScript(title)
        let htmlBody: String
        if let body = body {
            htmlBody = escapeForAppleScript(body)
        } else {
            htmlBody = ""
        }

        let script: String
        if let folderId = folderId {
            let escapedFolderId = escapeForAppleScript(folderId)
            script = """
                tell application "Notes"
                    try
                        set targetFolder to first folder of default account whose id is "\(escapedFolderId)"
                    on error
                        error "FOLDER_NOT_FOUND"
                    end try
                    set newNote to make new note at targetFolder with properties {name:"\(escapedTitle)", body:"\(htmlBody)"}
                    return id of newNote
                end tell
                """
        } else {
            script = """
                tell application "Notes"
                    set newNote to make new note at default account with properties {name:"\(escapedTitle)", body:"\(htmlBody)"}
                    return id of newNote
                end tell
                """
        }

        let result: String
        do {
            result = try await runner.run(script: script, timeout: 15)
        } catch let error as AppleScriptError {
            if case .executionFailed(let message) = error,
               message.contains("FOLDER_NOT_FOUND") {
                throw ValidationError.notFound(resource: "folder", id: folderId ?? "unknown")
            }
            throw error
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func openNote(id: String) async throws {
        let escapedId = escapeForAppleScript(id)
        let script = """
            tell application "Notes"
                try
                    set theNote to first note of default account whose id is "\(escapedId)"
                    show theNote
                    activate
                on error
                    error "NOTE_NOT_FOUND"
                end try
            end tell
            """

        do {
            _ = try await runner.run(script: script, timeout: 10)
        } catch let error as AppleScriptError {
            if case .executionFailed(let message) = error,
               message.contains("NOTE_NOT_FOUND") {
                throw ValidationError.notFound(resource: "note", id: id)
            }
            throw error
        }
    }

    // MARK: - Private Helpers

    private func buildFetchAllScript(limit: Int, includeBody: Bool) -> String {
        let bodyClause = includeBody
            ? "set nBody to body of theNote"
            : "set nBody to \"\""

        return """
            tell application "Notes"
                set resultList to {}
                set allNotes to every note of default account
                set nCount to count of allNotes
                if nCount > \(limit) then set nCount to \(limit)
                repeat with i from 1 to nCount
                    set theNote to item i of allNotes
                    set nId to id of theNote
                    set nName to name of theNote
                    set nModDate to modification date of theNote
                    \(bodyClause)
                    set end of resultList to nId & "\\t" & nName & "\\t" & (nModDate as string) & "\\t" & nBody & "\\n"
                end repeat
                return resultList as string
            end tell
            """
    }

    private func buildSearchScript(query: String, limit: Int, includeBody: Bool) -> String {
        let escapedQuery = escapeForAppleScript(query)
        let bodyClause = includeBody
            ? "set nBody to body of theNote"
            : "set nBody to \"\""

        return """
            tell application "Notes"
                set resultList to {}
                set matchedNotes to (every note of default account whose name contains "\(escapedQuery)")
                set nCount to count of matchedNotes
                if nCount > \(limit) then set nCount to \(limit)
                repeat with i from 1 to nCount
                    set theNote to item i of matchedNotes
                    set nId to id of theNote
                    set nName to name of theNote
                    set nModDate to modification date of theNote
                    \(bodyClause)
                    set end of resultList to nId & "\\t" & nName & "\\t" & (nModDate as string) & "\\t" & nBody & "\\n"
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

    /// Converts an AppleScript date string to ISO 8601 format.
    private func convertDateToISO8601(_ dateString: String) -> String {
        // AppleScript returns dates like "Saturday, January 31, 2026 at 7:49:36 PM"
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm:ss a"

        if let date = formatter.date(from: dateString) {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return isoFormatter.string(from: date)
        }
        // Fall back to raw string if parsing fails
        return dateString
    }

    /// Parses tab-delimited note response into `NoteData` array.
    private func parseNoteResponse(_ response: String, includeBody: Bool) -> [NoteData] {
        let lines = response.components(separatedBy: "\n").filter { !$0.isEmpty }

        return lines.compactMap { line -> NoteData? in
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 3 else { return nil }

            let id = parts[0]
            let title = parts[1]
            let modifiedAt = convertDateToISO8601(parts[2])
            let body: String?
            if includeBody && parts.count > 3 && !parts[3].isEmpty {
                body = parts[3]
            } else {
                body = nil
            }

            return NoteData(
                id: id,
                title: title,
                body: body,
                folderId: nil,
                modifiedAt: modifiedAt
            )
        }
    }

    /// Parses a single note response (id\ttitle\tdate\tbody).
    private func parseSingleNote(_ response: String) -> NoteData? {
        let parts = response.components(separatedBy: "\t")
        guard parts.count >= 3 else { return nil }

        let id = parts[0]
        let title = parts[1]
        let modifiedAt = convertDateToISO8601(parts[2])
        let body = parts.count > 3 ? parts[3] : nil

        return NoteData(
            id: id,
            title: title,
            body: body,
            folderId: nil,
            modifiedAt: modifiedAt
        )
    }
}
