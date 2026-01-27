import Foundation

/// Error indicating a database is locked by another process.
///
/// This error is separate from ``SQLiteError`` because database locks are
/// typically transient and can often be resolved by retrying after a short delay.
///
/// ## Common Causes
/// - Another application (e.g., Messages.app) is actively using the database
/// - A backup process is running
/// - System maintenance is in progress
///
/// ## Recommended Handling
/// Retry the operation after a brief delay (1-2 seconds).
///
/// ## Example
/// ```swift
/// do {
///     let messages = try messageAdapter.readMessages()
/// } catch let error as DatabaseLockedError {
///     print(error.userMessage)
///     // "Messages database is currently locked by another process..."
/// }
/// ```
public struct DatabaseLockedError: Error, Sendable {
    /// The name of the database that is locked (e.g., "Messages", "Mail").
    public let database: String

    /// Creates a new database locked error.
    /// - Parameter database: The name of the locked database.
    public init(database: String) {
        self.database = database
    }

    /// A user-friendly message describing the error and suggesting a retry.
    public var userMessage: String {
        return "\(database) database is currently locked by another process. Try again in a moment."
    }
}
