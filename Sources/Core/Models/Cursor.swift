import Foundation

/// Opaque cursor for pagination, encoded as base64 JSON.
public struct Cursor: Codable, Sendable {
    public let lastId: String
    public let ts: Int

    public init(lastId: String, ts: Int) {
        self.lastId = lastId
        self.ts = ts
    }

    /// Encode cursor to base64 string for transmission.
    public func encode() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(self) else {
            return ""
        }
        return data.base64EncodedString()
    }

    /// Decode cursor from base64 string.
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
