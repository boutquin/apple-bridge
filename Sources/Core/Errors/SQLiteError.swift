import Foundation

/// Error type for SQLite database operations.
public enum SQLiteError: Error, Sendable {
    case databaseNotFound(path: String)
    case openFailed(code: Int32)
    case queryFailed(message: String)
    case unsupportedSchema(details: String)

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
