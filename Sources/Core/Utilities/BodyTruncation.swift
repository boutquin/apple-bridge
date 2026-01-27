import Foundation

/// Default body truncation limit (100KB).
///
/// This limit prevents excessively large text bodies from consuming too much
/// memory or bandwidth when returned via MCP.
public let defaultBodyLimit = 100_000

/// Truncates body text if it exceeds the specified limit.
///
/// When text is truncated, the suffix "[truncated]" is appended to indicate
/// that the content was cut off.
///
/// - Parameters:
///   - body: The body text to truncate.
///   - limit: Maximum character count. Defaults to ``defaultBodyLimit`` (100KB).
/// - Returns: The original text if within limit, or truncated text with "[truncated]" suffix.
///
/// ## Example
/// ```swift
/// let shortText = "Hello, World!"
/// truncateBody(shortText)  // "Hello, World!"
///
/// let longText = String(repeating: "x", count: 200_000)
/// truncateBody(longText)   // First 100,000 chars + "[truncated]"
/// ```
public func truncateBody(_ body: String, limit: Int = defaultBodyLimit) -> String {
    if body.count <= limit {
        return body
    }
    let truncated = String(body.prefix(limit))
    return truncated + "[truncated]"
}

/// Truncates optional body text if it exceeds the specified limit.
///
/// This overload handles optional strings, passing through `nil` unchanged.
///
/// - Parameters:
///   - body: The optional body text to truncate.
///   - limit: Maximum character count. Defaults to ``defaultBodyLimit`` (100KB).
/// - Returns: `nil` if input was `nil`, otherwise truncated text with "[truncated]" suffix if over limit.
///
/// ## Example
/// ```swift
/// let optionalText: String? = nil
/// truncateBody(optionalText)  // nil
///
/// let someText: String? = "Hello"
/// truncateBody(someText)      // "Hello"
/// ```
public func truncateBody(_ body: String?, limit: Int = defaultBodyLimit) -> String? {
    guard let unwrapped = body else { return nil }
    // Call the non-optional overload explicitly
    let result: String = truncateBody(unwrapped, limit: limit)
    return result
}
