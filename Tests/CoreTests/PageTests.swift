import Testing
import Foundation
@testable import Core

@Suite("Page<T> Tests")
struct PageTests {
    @Test func testPageEncodesCorrectly() throws {
        let page = Page(items: ["a", "b"], nextCursor: "abc", hasMore: true)
        let json = try JSONEncoder().encode(page)
        let decoded = try JSONDecoder().decode(Page<String>.self, from: json)
        #expect(decoded.items == ["a", "b"])
        #expect(decoded.nextCursor == "abc")
        #expect(decoded.hasMore == true)
    }

    @Test func testPageWithNilCursor() throws {
        let page = Page(items: [1, 2, 3], nextCursor: nil, hasMore: false)
        let json = try JSONEncoder().encode(page)
        let str = String(data: json, encoding: .utf8)!
        #expect(str.contains("\"hasMore\":false"))

        let decoded = try JSONDecoder().decode(Page<Int>.self, from: json)
        #expect(decoded.nextCursor == nil)
        #expect(decoded.hasMore == false)
    }

    @Test func testPageWithEmptyItems() throws {
        let page = Page<String>(items: [], nextCursor: nil, hasMore: false)
        let json = try JSONEncoder().encode(page)
        let decoded = try JSONDecoder().decode(Page<String>.self, from: json)
        #expect(decoded.items.isEmpty)
    }
}
