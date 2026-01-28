import Foundation
import Core

/// Utilities for validating SQLite database schemas.
///
/// These validators ensure that macOS system databases (Notes, Messages) have the expected
/// schema before attempting to query them. This catches issues early when:
/// - A newer macOS version changes the database format
/// - The database file is corrupted
/// - The wrong file is being accessed
///
/// ## Usage
/// ```swift
/// let db = try SQLiteConnection(path: notesDBPath, readOnly: true)
/// try SchemaValidator.validateNotesSchema(db)
/// // Now safe to query the Notes database
/// ```
public enum SchemaValidator {

    // MARK: - Notes Schema

    /// Required table for Notes database.
    private static let notesRequiredTables = ["ZICCLOUDSYNCINGOBJECT"]

    /// Required columns in the Notes ZICCLOUDSYNCINGOBJECT table.
    private static let notesRequiredColumns: [String: [String]] = [
        "ZICCLOUDSYNCINGOBJECT": ["Z_PK", "ZTITLE1", "ZSNIPPET", "ZMODIFICATIONDATE1"]
    ]

    /// Validates that the database has the expected Notes schema.
    ///
    /// - Parameter db: An open SQLite connection to validate.
    /// - Throws: `SQLiteError.unsupportedSchema` if required tables or columns are missing.
    public static func validateNotesSchema(_ db: SQLiteConnection) throws {
        try validate(
            db,
            requiredTables: notesRequiredTables,
            requiredColumns: notesRequiredColumns
        )
    }

    // MARK: - Messages Schema

    /// Required tables for Messages database.
    private static let messagesRequiredTables = ["message", "chat", "handle"]

    /// Required columns in Messages tables.
    private static let messagesRequiredColumns: [String: [String]] = [
        "message": ["ROWID", "text", "date"],
        "chat": ["ROWID", "chat_identifier"],
        "handle": ["ROWID", "id"]
    ]

    /// Validates that the database has the expected Messages schema.
    ///
    /// - Parameter db: An open SQLite connection to validate.
    /// - Throws: `SQLiteError.unsupportedSchema` if required tables or columns are missing.
    public static func validateMessagesSchema(_ db: SQLiteConnection) throws {
        try validate(
            db,
            requiredTables: messagesRequiredTables,
            requiredColumns: messagesRequiredColumns
        )
    }

    // MARK: - Generic Validation

    /// Validates that a database has the expected tables and columns.
    ///
    /// - Parameters:
    ///   - db: An open SQLite connection to validate.
    ///   - requiredTables: List of table names that must exist.
    ///   - requiredColumns: Dictionary mapping table names to required column names.
    /// - Throws: `SQLiteError.unsupportedSchema` if validation fails.
    public static func validate(
        _ db: SQLiteConnection,
        requiredTables: [String],
        requiredColumns: [String: [String]]
    ) throws {
        // Get list of all tables
        let existingTables = try getTableNames(db)

        // Check required tables exist
        for table in requiredTables {
            guard existingTables.contains(table) else {
                throw SQLiteError.unsupportedSchema(
                    details: "Missing required table: \(table). Found tables: \(existingTables.joined(separator: ", "))"
                )
            }
        }

        // Check required columns for each table
        for (table, columns) in requiredColumns {
            let existingColumns = try getColumnNames(db, table: table)

            for column in columns {
                guard existingColumns.contains(column) else {
                    throw SQLiteError.unsupportedSchema(
                        details: "Missing required column '\(column)' in table '\(table)'. Found columns: \(existingColumns.joined(separator: ", "))"
                    )
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Gets all table names in the database.
    private static func getTableNames(_ db: SQLiteConnection) throws -> Set<String> {
        let results = try db.query(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
        )

        var tableNames: Set<String> = []
        for row in results {
            if let name = row["name"] as? String {
                tableNames.insert(name)
            }
        }
        return tableNames
    }

    /// Gets column names for a specific table.
    private static func getColumnNames(_ db: SQLiteConnection, table: String) throws -> Set<String> {
        // Use PRAGMA table_info to get column details
        let results = try db.query("PRAGMA table_info(\(table))")

        var columnNames: Set<String> = []
        for row in results {
            if let name = row["name"] as? String {
                columnNames.insert(name)
            }
        }
        return columnNames
    }
}
