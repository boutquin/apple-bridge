import Foundation
import Core

/// Utilities for checking macOS permissions and database access.
///
/// Several apple-bridge features require Full Disk Access (FDA) to read macOS system databases:
/// - Notes: `~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite`
/// - Messages: `~/Library/Messages/chat.db`
///
/// These utilities help check permissions and provide clear error messages when access is denied.
///
/// ## Usage
/// ```swift
/// guard PermissionChecks.hasFullDiskAccess() else {
///     throw PermissionChecks.fdaRequiredError(for: "Notes")
/// }
/// ```
public enum PermissionChecks {

    // MARK: - Full Disk Access

    /// Checks if the process has Full Disk Access.
    ///
    /// This is a heuristic check that attempts to read a protected file.
    /// It may return `true` even if FDA is not fully granted, but will
    /// catch most cases where FDA is completely denied.
    ///
    /// - Returns: `true` if FDA appears to be granted, `false` otherwise.
    public static func hasFullDiskAccess() -> Bool {
        // Try to access a protected directory that requires FDA
        // Safari's history is a good indicator (requires FDA but doesn't change often)
        let safariPath = NSHomeDirectory() + "/Library/Safari/History.db"

        // If the file exists and is readable, FDA is likely granted
        if FileManager.default.isReadableFile(atPath: safariPath) {
            return true
        }

        // Also check Notes path as a fallback
        let notesPath = notesDatabasePath()
        if FileManager.default.isReadableFile(atPath: notesPath) {
            return true
        }

        // Check Messages path
        let messagesPath = messagesDatabasePath()
        if FileManager.default.isReadableFile(atPath: messagesPath) {
            return true
        }

        return false
    }

    // MARK: - Database Paths

    /// Returns the path to the Notes SQLite database.
    ///
    /// On macOS, Notes stores data in:
    /// `~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite`
    public static func notesDatabasePath() -> String {
        let home = NSHomeDirectory()
        return "\(home)/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite"
    }

    /// Returns the path to the Messages SQLite database.
    ///
    /// On macOS, Messages stores data in:
    /// `~/Library/Messages/chat.db`
    public static func messagesDatabasePath() -> String {
        let home = NSHomeDirectory()
        return "\(home)/Library/Messages/chat.db"
    }

    // MARK: - Database Accessibility

    /// Checks if the Notes database is accessible.
    ///
    /// - Returns: `true` if the database file exists and is readable.
    public static func canAccessNotesDatabase() -> Bool {
        let path = notesDatabasePath()
        return FileManager.default.isReadableFile(atPath: path)
    }

    /// Checks if the Messages database is accessible.
    ///
    /// - Returns: `true` if the database file exists and is readable.
    public static func canAccessMessagesDatabase() -> Bool {
        let path = messagesDatabasePath()
        return FileManager.default.isReadableFile(atPath: path)
    }

    // MARK: - Error Generation

    /// Creates a PermissionError for Full Disk Access denial.
    ///
    /// The error includes remediation steps that guide the user to
    /// System Settings > Privacy & Security > Full Disk Access.
    ///
    /// - Parameter appName: The name of the app/feature that requires FDA (e.g., "Notes", "Messages").
    /// - Returns: A `PermissionError.fullDiskAccessDenied` with helpful context.
    public static func fdaRequiredError(for appName: String) -> PermissionError {
        return .fullDiskAccessDenied(context: appName)
    }
}
