import Foundation
import SQLite3
import Core

/// A lightweight wrapper around SQLite3 for database access.
///
/// `SQLiteConnection` provides a simple interface for querying macOS system databases
/// (e.g., Notes, Messages). It supports read-only mode (default) for safely reading
/// system databases, or read-write mode for testing and creating new databases.
/// It handles connection management, busy timeouts, and query execution with proper
/// error handling.
///
/// ## Usage
/// ```swift
/// let db = try SQLiteConnection(path: "/path/to/database.sqlite", readOnly: true)
/// let results = try db.query("SELECT * FROM notes WHERE title LIKE ?", parameters: ["%meeting%"])
/// for row in results {
///     print(row["title"] as? String)
/// }
/// db.close()
/// ```
///
/// ## Thread Safety
/// `SQLiteConnection` is `Sendable` but SQLite connections themselves are not thread-safe.
/// Each connection should be used from a single task/thread at a time.
public final class SQLiteConnection: @unchecked Sendable {
    private var db: OpaquePointer?
    private let path: String
    private let lock = NSLock()

    /// Whether the database connection is currently open.
    public var isOpen: Bool {
        lock.lock()
        defer { lock.unlock() }
        return db != nil
    }

    /// Creates a new SQLite connection.
    ///
    /// - Parameters:
    ///   - path: Path to the SQLite database file.
    ///   - readOnly: Whether to open the database in read-only mode. Defaults to `true`.
    ///   - busyTimeoutMs: Busy timeout in milliseconds. Defaults to 5000ms (5 seconds).
    /// - Throws: `SQLiteError.databaseNotFound` if the file doesn't exist,
    ///           `SQLiteError.openFailed` if the connection fails.
    public init(path: String, readOnly: Bool = true, busyTimeoutMs: Int32 = 5000) throws {
        self.path = path

        // Check if file exists first (only for read-only mode)
        if readOnly {
            guard FileManager.default.fileExists(atPath: path) else {
                throw SQLiteError.databaseNotFound(path: path)
            }
        }

        let flags = readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)

        let result = sqlite3_open_v2(path, &db, flags, nil)
        guard result == SQLITE_OK else {
            let code = result
            db = nil
            throw SQLiteError.openFailed(code: code)
        }

        // Set busy timeout
        sqlite3_busy_timeout(db, busyTimeoutMs)
    }

    deinit {
        close()
    }

    /// Closes the database connection.
    ///
    /// After calling this method, any further queries will throw an error.
    /// It's safe to call this method multiple times.
    public func close() {
        lock.lock()
        defer { lock.unlock() }

        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    /// Executes a SQL query and returns the results.
    ///
    /// - Parameters:
    ///   - sql: The SQL query to execute.
    ///   - parameters: Optional parameters to bind to the query (using `?` placeholders).
    /// - Returns: An array of dictionaries, where each dictionary represents a row
    ///            with column names as keys.
    /// - Throws: `SQLiteError.queryFailed` if the query fails or the connection is closed.
    public func query(_ sql: String, parameters: [Any?] = []) throws -> [[String: Any?]] {
        lock.lock()
        defer { lock.unlock() }

        guard let db = db else {
            throw SQLiteError.queryFailed(message: "Database connection is closed")
        }

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)

        guard prepareResult == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.queryFailed(message: errorMessage)
        }

        defer {
            sqlite3_finalize(statement)
        }

        // Bind parameters
        guard let stmt = statement else {
            throw SQLiteError.queryFailed(message: "Failed to prepare statement")
        }

        for (index, param) in parameters.enumerated() {
            let bindIndex = Int32(index + 1) // SQLite uses 1-based indexing
            try bindParameter(statement: stmt, index: bindIndex, value: param)
        }

        // Execute and collect results
        var results: [[String: Any?]] = []
        let columnCount = sqlite3_column_count(statement)

        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any?] = [:]

            for i in 0..<columnCount {
                let columnName = String(cString: sqlite3_column_name(statement, i))
                let columnType = sqlite3_column_type(statement, i)

                let value: Any?
                switch columnType {
                case SQLITE_INTEGER:
                    value = sqlite3_column_int64(statement, i)
                case SQLITE_FLOAT:
                    value = sqlite3_column_double(statement, i)
                case SQLITE_TEXT:
                    if let text = sqlite3_column_text(statement, i) {
                        value = String(cString: text)
                    } else {
                        value = nil
                    }
                case SQLITE_BLOB:
                    if let blob = sqlite3_column_blob(statement, i) {
                        let length = sqlite3_column_bytes(statement, i)
                        value = Data(bytes: blob, count: Int(length))
                    } else {
                        value = nil
                    }
                case SQLITE_NULL:
                    value = nil
                default:
                    value = nil
                }

                row[columnName] = value
            }

            results.append(row)
        }

        return results
    }

    // MARK: - Private Helpers

    private func bindParameter(statement: OpaquePointer, index: Int32, value: Any?) throws {
        guard let db = db else { return }

        let result: Int32

        switch value {
        case nil:
            result = sqlite3_bind_null(statement, index)
        case let intValue as Int:
            result = sqlite3_bind_int64(statement, index, Int64(intValue))
        case let int64Value as Int64:
            result = sqlite3_bind_int64(statement, index, int64Value)
        case let doubleValue as Double:
            result = sqlite3_bind_double(statement, index, doubleValue)
        case let stringValue as String:
            result = sqlite3_bind_text(statement, index, stringValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        case let dataValue as Data:
            result = dataValue.withUnsafeBytes { bytes in
                sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(dataValue.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            }
        default:
            // Try to convert to string for any non-nil value
            if let actualValue = value {
                let stringValue = String(describing: actualValue)
                result = sqlite3_bind_text(statement, index, stringValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else {
                result = sqlite3_bind_null(statement, index)
            }
        }

        if result != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw SQLiteError.queryFailed(message: "Failed to bind parameter at index \(index): \(errorMessage)")
        }
    }
}
