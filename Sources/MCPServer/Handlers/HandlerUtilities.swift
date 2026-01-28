import Foundation
import MCP
import Core

/// Shared utilities for MCP tool handlers.
///
/// Provides common functionality for argument extraction, response formatting,
/// and error handling used across all domain handlers.
enum HandlerUtilities {

    // MARK: - Argument Extraction

    /// Extracts a string value from MCP arguments.
    /// - Parameters:
    ///   - arguments: The arguments dictionary from the MCP call.
    ///   - key: The key to look up.
    /// - Returns: The string value if present and valid, otherwise `nil`.
    static func extractString(from arguments: [String: Value]?, key: String) -> String? {
        guard let arguments, let value = arguments[key] else { return nil }
        switch value {
        case .string(let str):
            return str
        default:
            return nil
        }
    }

    /// Extracts an integer value from MCP arguments.
    ///
    /// Handles both `.int` and `.double` value types (truncating doubles to integers).
    ///
    /// - Parameters:
    ///   - arguments: The arguments dictionary from the MCP call.
    ///   - key: The key to look up.
    /// - Returns: The integer value if present and valid, otherwise `nil`.
    static func extractInt(from arguments: [String: Value]?, key: String) -> Int? {
        guard let arguments, let value = arguments[key] else { return nil }
        switch value {
        case .int(let num):
            return num
        case .double(let num):
            return Int(num)
        default:
            return nil
        }
    }

    /// Extracts a boolean value from MCP arguments.
    /// - Parameters:
    ///   - arguments: The arguments dictionary from the MCP call.
    ///   - key: The key to look up.
    /// - Returns: The boolean value if present and valid, otherwise `nil`.
    static func extractBool(from arguments: [String: Value]?, key: String) -> Bool? {
        guard let arguments, let value = arguments[key] else { return nil }
        switch value {
        case .bool(let b):
            return b
        default:
            return nil
        }
    }

    // MARK: - Response Formatting

    /// Creates a success result from an Encodable value.
    ///
    /// Encodes the value as pretty-printed JSON with sorted keys for consistent output.
    ///
    /// - Parameter value: The value to encode.
    /// - Returns: A `CallTool.Result` with the JSON-encoded content.
    static func successResult<T: Encodable>(_ value: T) -> CallTool.Result {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            let json = String(data: data, encoding: .utf8) ?? "{}"
            return CallTool.Result(content: [.text(json)], isError: false)
        } catch {
            return CallTool.Result(
                content: [.text("Error encoding result: \(error.localizedDescription)")],
                isError: true
            )
        }
    }

    /// Creates an error result from an Error.
    ///
    /// Extracts user-friendly messages from known error types (`ValidationError`,
    /// `PermissionError`) and falls back to `localizedDescription` for others.
    ///
    /// - Parameter error: The error to format.
    /// - Returns: A `CallTool.Result` with `isError: true`.
    static func errorResult(_ error: Error) -> CallTool.Result {
        let message: String
        switch error {
        case let validationError as ValidationError:
            message = validationError.userMessage
        case let permissionError as PermissionError:
            message = permissionError.userMessage
        default:
            message = error.localizedDescription
        }
        return CallTool.Result(
            content: [.text("Error: \(message)")],
            isError: true
        )
    }

    /// Creates an error result for a missing required parameter.
    /// - Parameter name: The name of the missing parameter.
    /// - Returns: A `CallTool.Result` with `isError: true`.
    static func missingRequiredParameter(_ name: String) -> CallTool.Result {
        CallTool.Result(
            content: [.text("Missing required parameter: \(name)")],
            isError: true
        )
    }
}
