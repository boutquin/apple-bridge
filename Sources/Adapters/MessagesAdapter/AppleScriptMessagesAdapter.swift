import Foundation
import Core

/// AppleScript implementation of `MessagesAdapterProtocol`.
///
/// Uses `osascript` to communicate with Messages.app. This bypasses the
/// Full Disk Access TCC requirement for chat listing and sending.
///
/// **Limitation:** Messages.app's AppleScript dictionary does not expose
/// individual message content (no `message` class in the scripting dictionary).
/// Reading message history (`fetchMessages`, `fetchUnreadMessages`) requires
/// direct SQLite access via `HybridMessagesAdapter` with Full Disk Access.
/// These methods throw `PermissionError.fullDiskAccessDenied` with a clear
/// explanation.
public struct AppleScriptMessagesAdapter: MessagesAdapterProtocol, Sendable {

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

    // MARK: - MessagesAdapterProtocol

    public func fetchChats(limit: Int) async throws -> [ChatData] {
        let script = """
            tell application "Messages"
                set resultList to {}
                set allChats to every chat
                set cCount to count of allChats
                if cCount > \(limit) then set cCount to \(limit)
                repeat with i from 1 to cCount
                    set theChat to item i of allChats
                    set cId to id of theChat
                    -- Build display name from participants
                    set pNames to {}
                    set allParticipants to every participant of theChat
                    repeat with p in allParticipants
                        set end of pNames to name of p
                    end repeat
                    if (count of pNames) > 0 then
                        set AppleScript's text item delimiters to ", "
                        set displayName to pNames as string
                        set AppleScript's text item delimiters to ""
                    else
                        set displayName to cId
                    end if
                    set end of resultList to cId & "\\t" & displayName & "\\n"
                end repeat
                return resultList as string
            end tell
            """

        let result = try await runner.run(script: script, timeout: 15)
        return parseChatResponse(result)
    }

    public func fetchMessages(chatId: String, limit: Int) async throws -> [MessageData] {
        // Messages.app's AppleScript dictionary does not expose individual messages.
        // Reading message history requires direct SQLite access (Full Disk Access).
        throw PermissionError.fullDiskAccessDenied(
            context: "Messages (reading message history requires Full Disk Access — Messages.app's AppleScript dictionary does not expose individual messages)"
        )
    }

    public func fetchUnreadMessages(limit: Int) async throws -> [MessageData] {
        // Messages.app's AppleScript dictionary does not expose individual messages.
        // Reading unread messages requires direct SQLite access (Full Disk Access).
        throw PermissionError.fullDiskAccessDenied(
            context: "Messages (reading message history requires Full Disk Access — Messages.app's AppleScript dictionary does not expose individual messages)"
        )
    }

    public func sendMessage(to: String, body: String) async throws {
        let escapedBody = escapeForAppleScript(body)
        let escapedTo = escapeForAppleScript(to)

        let script = """
            tell application "Messages"
                set targetService to 1st service whose service type = iMessage
                set targetBuddy to buddy "\(escapedTo)" of targetService
                send "\(escapedBody)" to targetBuddy
            end tell
            """

        _ = try await runner.run(script: script, timeout: 15)
    }

    public func scheduleMessage(to: String, body: String, sendAt: String) async throws {
        // Messages.app does not support scheduled messages
        throw AppleScriptError.executionFailed(
            message: "Scheduled messages are not supported. Messages.app does not have native scheduling support."
        )
    }

    // MARK: - Private Helpers

    /// Escapes a string for safe use inside AppleScript double-quoted strings.
    private func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Parses tab-delimited chat response into `ChatData` array.
    private func parseChatResponse(_ response: String) -> [ChatData] {
        let lines = response.components(separatedBy: "\n").filter { !$0.isEmpty }

        return lines.compactMap { line -> ChatData? in
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { return nil }

            let id = parts[0]
            let displayName = parts[1]

            return ChatData(
                id: id,
                displayName: displayName
            )
        }
    }
}
