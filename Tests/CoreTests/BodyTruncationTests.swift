import Testing
import Foundation
@testable import Core

@Suite("Body Truncation Tests")
struct BodyTruncationTests {
    @Test func testTruncateBodyUnderLimit() {
        let body = "Short body"
        let result = truncateBody(body, limit: 100_000)
        #expect(result == body)
    }

    @Test func testTruncateBodyOverLimit() {
        let largeBody = String(repeating: "x", count: 150_000)
        let result = truncateBody(largeBody, limit: 100_000)

        #expect(result.count <= 100_000 + "[truncated]".count)
        #expect(result.hasSuffix("[truncated]"))
    }

    @Test func testTruncateBodyExactlyAtLimit() {
        let body = String(repeating: "y", count: 100_000)
        let result = truncateBody(body, limit: 100_000)
        #expect(result == body)
    }

    @Test func testTruncateBodyEmptyString() {
        let result = truncateBody("", limit: 100_000)
        #expect(result == "")
    }

    @Test func testTruncateBodyJustOverLimit() {
        let body = String(repeating: "z", count: 100_001)
        let result = truncateBody(body, limit: 100_000)
        #expect(result.hasSuffix("[truncated]"))
        #expect(result.count == 100_000 + "[truncated]".count)
    }

    @Test func testTruncateBodyNilReturnsNil() {
        let result = truncateBody(nil, limit: 100_000)
        #expect(result == nil)
    }

    @Test func testTruncateBodyDefaultLimit() {
        // Default limit should be 100KB
        let largeBody = String(repeating: "a", count: 150_000)
        let result = truncateBody(largeBody)
        #expect(result.hasSuffix("[truncated]"))
    }
}
