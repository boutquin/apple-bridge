import Foundation

/// Errors from SQLite database operations.
///
/// These errors occur when reading from macOS system databases (e.g., Messages, Mail).
/// For database lock conflicts, see ``DatabaseLockedError``.
///
/// ## Common Causes
/// - `databaseNotFound`: Database file doesn't exist or path is incorrect
/// - `openFailed`: Database is corrupted or incompatible
/// - `queryFailed`: SQL syntax error or schema mismatch
/// - `unsupportedSchema`: macOS version uses an incompatible database format
///
/// ## Example
/// ```swift
/// do {
///     let messages = try messageAdapter.readMessages()
/// } catch let error as SQLiteError {
///     print(error.userMessage)
/// }
/// ```
public enum SQLiteError: Error, Sendable {
    /// The database file was not found at the expected path.
    case databaseNotFound(path: String)

    /// Failed to open the database connection.
    case openFailed(code: Int32)

    /// A SQL query failed to execute.
    case queryFailed(message: String)

    /// The database schema is not supported (possibly a newer macOS version).
    case unsupportedSchema(details: String)

    /// A user-friendly message describing the error.
    public var userMessage: String {
        switch self {
        case .databaseNotFound(let path):
            return "Database not found at path: \(path)"
        case .openFailed(let code):
            return "Failed to open database (SQLite error code: \(code))"
        case .queryFailed(let message):
            return "Database query failed: \(message)"
        case .unsupportedSchema(let details):
            return "Unsupported database schema: \(details)"
        }
    }
}
