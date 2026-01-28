import Foundation
import Core

/// Utilities for validating and projecting database field selections.
///
/// When clients request specific fields from a database query, `FieldsProjection`
/// validates that the requested fields exist in the allowed set. This prevents
/// SQL injection and provides clear error messages for typos or unsupported fields.
///
/// ## Usage
/// ```swift
/// let allowed = ["id", "title", "date", "sender"]
/// let requested = try FieldsProjection.validate(["id", "title"], allowed: allowed)
/// // requested == ["id", "title"]
///
/// let invalid = try FieldsProjection.validate(["id", "bad_field"], allowed: allowed)
/// // throws ValidationError.invalidField(field: "bad_field", allowed: allowed)
/// ```
public enum FieldsProjection {

    /// Validates that all requested fields are in the allowed set.
    ///
    /// - Parameters:
    ///   - requested: The fields requested by the client.
    ///   - allowed: The set of valid field names.
    /// - Returns: The validated fields (with duplicates removed, order preserved).
    /// - Throws: `ValidationError.invalidField` if any requested field is not allowed.
    public static func validate(_ requested: [String], allowed: [String]) throws -> [String] {
        let allowedSet = Set(allowed)
        var seen = Set<String>()
        var result: [String] = []

        for field in requested {
            // Check if field is valid
            guard allowedSet.contains(field) else {
                throw ValidationError.invalidField(field: field, allowed: allowed)
            }

            // Deduplicate while preserving order
            if !seen.contains(field) {
                seen.insert(field)
                result.append(field)
            }
        }

        return result
    }

    /// Validates requested fields or returns defaults.
    ///
    /// If `requested` is nil or empty, returns the default fields.
    /// Otherwise validates and returns the requested fields.
    ///
    /// - Parameters:
    ///   - requested: The fields requested by the client (nil or empty means use defaults).
    ///   - allowed: The set of valid field names.
    ///   - default: The default fields to use when none are requested.
    /// - Returns: The validated fields or defaults.
    /// - Throws: `ValidationError.invalidField` if any requested field is not allowed.
    public static func validateOrDefault(
        _ requested: [String]?,
        allowed: [String],
        default defaultFields: [String]
    ) throws -> [String] {
        guard let requested = requested, !requested.isEmpty else {
            return defaultFields
        }
        return try validate(requested, allowed: allowed)
    }
}
