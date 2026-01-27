import Foundation

/// Error type for database lock conflicts.
/// Separate from SQLiteError for clearer error handling and user messaging.
public struct DatabaseLockedError: Error, Sendable {
    public let database: String

    public init(database: String) {
        self.database = database
    }

    public var userMessage: String {
        return "\(database) database is currently locked by another process. Try again in a moment."
    }
}
