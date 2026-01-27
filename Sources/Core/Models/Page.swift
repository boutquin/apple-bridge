import Foundation

/// Generic paginated response wrapper.
public struct Page<T: Codable & Sendable>: Codable, Sendable {
    public let items: [T]
    public let nextCursor: String?
    public let hasMore: Bool

    public init(items: [T], nextCursor: String?, hasMore: Bool) {
        self.items = items
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}
