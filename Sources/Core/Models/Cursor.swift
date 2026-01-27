import Foundation

/// An opaque cursor for cursor-based pagination.
///
/// `Cursor` encapsulates pagination state as a base64-encoded JSON string,
/// hiding implementation details from API consumers. The cursor tracks the
/// last item ID and timestamp to enable efficient database queries.
///
/// ## Usage
/// ```swift
/// // Create and encode a cursor
/// let cursor = Cursor(lastId: "event-123", ts: 1706400000)
/// let encoded = try cursor.encode()  // "eyJsYXN0SWQiOi..."
///
/// // Decode a cursor from a client request
/// let decoded = try Cursor.decode(encoded)
/// ```
///
/// ## Implementation Notes
/// - Uses sorted keys for deterministic encoding
/// - Timestamps are Unix epoch seconds
public struct Cursor: Codable, Sendable {
    /// The ID of the last item in the previous page.
    public let lastId: String

    /// Unix timestamp (seconds) of the last item, used for tie-breaking.
    public let ts: Int

    /// Creates a new cursor.
    /// - Parameters:
    ///   - lastId: The ID of the last item in the current page.
    ///   - ts: Unix timestamp of the last item.
    public init(lastId: String, ts: Int) {
        self.lastId = lastId
        self.ts = ts
    }

    /// Encodes the cursor to a base64 string for transmission to clients.
    /// - Returns: A base64-encoded JSON string representing this cursor.
    /// - Throws: `ValidationError.invalidCursor` if encoding fails.
    public func encode() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        do {
            let data = try encoder.encode(self)
            return data.base64EncodedString()
        } catch {
            throw ValidationError.invalidCursor(reason: "Failed to encode cursor: \(error.localizedDescription)")
        }
    }

    /// Decodes a cursor from a base64 string received from a client.
    /// - Parameter string: The base64-encoded cursor string.
    /// - Returns: The decoded `Cursor` instance.
    /// - Throws: `ValidationError.invalidCursor` if the string is empty, not valid base64, or not valid JSON.
    public static func decode(_ string: String) throws -> Cursor {
        guard !string.isEmpty else {
            throw ValidationError.invalidCursor(reason: "Empty cursor string")
        }

        guard let data = Data(base64Encoded: string) else {
            throw ValidationError.invalidCursor(reason: "Invalid base64 encoding")
        }

        do {
            return try JSONDecoder().decode(Cursor.self, from: data)
        } catch {
            throw ValidationError.invalidCursor(reason: "Invalid cursor format")
        }
    }
}
