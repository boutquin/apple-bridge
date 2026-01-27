import Foundation

/// Errors from input validation failures.
///
/// These errors occur when client-provided input doesn't meet the expected format
/// or constraints. Each error provides a user-friendly message explaining what
/// was wrong and what was expected.
///
/// ## Common Uses
/// - `missingRequired`: A required parameter was not provided
/// - `invalidFormat`: A parameter was provided but in the wrong format
/// - `invalidCursor`: A pagination cursor couldn't be decoded
/// - `invalidField`: An unknown field name was requested
///
/// ## Example
/// ```swift
/// guard !title.isEmpty else {
///     throw ValidationError.missingRequired(field: "title")
/// }
///
/// guard let date = ISO8601DateFormatter().date(from: dateString) else {
///     throw ValidationError.invalidFormat(field: "startDate", expected: "ISO8601")
/// }
/// ```
public enum ValidationError: Error, Sendable {
    /// A required field was not provided.
    case missingRequired(field: String)

    /// A field was provided but in an invalid format.
    case invalidFormat(field: String, expected: String)

    /// A pagination cursor was invalid or malformed.
    case invalidCursor(reason: String)

    /// An unknown field name was requested (e.g., in a sort or filter).
    case invalidField(field: String, allowed: [String])

    /// A user-friendly message describing the validation error.
    public var userMessage: String {
        switch self {
        case .missingRequired(let field):
            return "Missing required field: \(field)"
        case .invalidFormat(let field, let expected):
            return "Invalid format for \(field). Expected: \(expected)"
        case .invalidCursor(let reason):
            return "Invalid cursor: \(reason)"
        case .invalidField(let field, let allowed):
            return "Invalid field '\(field)'. Valid fields: \(allowed.joined(separator: ", "))"
        }
    }
}
