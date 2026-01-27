import Foundation

/// Default body truncation limit (100KB).
public let defaultBodyLimit = 100_000

/// Truncate body text if it exceeds the limit.
/// - Parameters:
///   - body: The body text to truncate.
///   - limit: Maximum character count (default 100KB).
/// - Returns: Truncated body with "[truncated]" suffix if over limit, otherwise original.
public func truncateBody(_ body: String, limit: Int = defaultBodyLimit) -> String {
    if body.count <= limit {
        return body
    }
    let truncated = String(body.prefix(limit))
    return truncated + "[truncated]"
}

/// Truncate optional body text if it exceeds the limit.
/// - Parameters:
///   - body: The optional body text to truncate.
///   - limit: Maximum character count (default 100KB).
/// - Returns: Truncated body with "[truncated]" suffix if over limit, nil if input was nil.
public func truncateBody(_ body: String?, limit: Int = defaultBodyLimit) -> String? {
    guard let body = body else { return nil }
    if body.count <= limit {
        return body
    }
    let truncated = String(body.prefix(limit))
    return truncated + "[truncated]"
}
