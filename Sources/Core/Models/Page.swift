import Foundation

/// A generic paginated response wrapper for list operations.
///
/// `Page` provides cursor-based pagination for any collection of items.
/// Use `nextCursor` to fetch subsequent pages and check `hasMore` to
/// determine if additional items exist.
///
/// ## Example
/// ```swift
/// let page = Page(
///     items: [event1, event2],
///     nextCursor: "eyJsYXN0SWQiOi...",
///     hasMore: true
/// )
/// ```
public struct Page<T: Codable & Sendable>: Codable, Sendable {
    /// The items in this page of results.
    public let items: [T]

    /// Opaque cursor for fetching the next page, or `nil` if this is the last page.
    public let nextCursor: String?

    /// Whether more items exist beyond this page.
    public let hasMore: Bool

    /// Creates a new page of results.
    /// - Parameters:
    ///   - items: The items in this page.
    ///   - nextCursor: Cursor for the next page, or `nil` if no more pages.
    ///   - hasMore: Whether additional pages exist.
    public init(items: [T], nextCursor: String?, hasMore: Bool) {
        self.items = items
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

// MARK: - Equatable

extension Page: Equatable where T: Equatable {}
