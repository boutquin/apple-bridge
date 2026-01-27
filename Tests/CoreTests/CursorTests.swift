import Testing
import Foundation
@testable import Core

@Suite("Cursor Tests")
struct CursorTests {
    @Test func testCursorEncodingRoundTrip() throws {
        let cursor = Cursor(lastId: "event-123", ts: 1706400000)
        let encoded = try cursor.encode()

        // Should be base64 (alphanumeric + / + = padding)
        #expect(encoded.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "/" || $0 == "=" })

        let decoded = try Cursor.decode(encoded)
        #expect(decoded.lastId == "event-123")
        #expect(decoded.ts == 1706400000)
    }

    @Test func testCursorDecodeInvalidThrows() {
        #expect(throws: ValidationError.self) {
            _ = try Cursor.decode("not-valid-base64!!!")
        }
    }

    @Test func testCursorWithSpecialCharactersInId() throws {
        let cursor = Cursor(lastId: "event/with:special@chars", ts: 1706400000)
        let encoded = try cursor.encode()
        let decoded = try Cursor.decode(encoded)
        #expect(decoded.lastId == "event/with:special@chars")
    }

    @Test func testCursorDecodeEmptyStringThrows() {
        #expect(throws: ValidationError.self) {
            _ = try Cursor.decode("")
        }
    }
}
