import Foundation

/// Error type for validation failures.
public enum ValidationError: Error, Sendable {
    case missingRequired(field: String)
    case invalidFormat(field: String, expected: String)
    case invalidCursor(reason: String)
    case invalidField(field: String, allowed: [String])

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
