import Testing
import Foundation
@testable import Adapters
import Core

/// Tests for field projection validation
@Suite("Fields Projection Tests")
struct FieldsProjectionTests {

    // MARK: - Valid Fields Tests

    @Test("validateFields accepts valid field subset")
    func testValidFieldsSubset() throws {
        let allowedFields = ["id", "title", "date", "sender"]
        let requested = ["id", "title"]

        let result = try FieldsProjection.validate(requested, allowed: allowedFields)
        #expect(result == ["id", "title"])
    }

    @Test("validateFields accepts all allowed fields")
    func testValidFieldsAll() throws {
        let allowedFields = ["id", "title", "date"]
        let requested = ["id", "title", "date"]

        let result = try FieldsProjection.validate(requested, allowed: allowedFields)
        #expect(result == ["id", "title", "date"])
    }

    @Test("validateFields accepts single field")
    func testValidFieldsSingle() throws {
        let allowedFields = ["id", "title", "date"]
        let requested = ["title"]

        let result = try FieldsProjection.validate(requested, allowed: allowedFields)
        #expect(result == ["title"])
    }

    @Test("validateFields preserves order")
    func testValidFieldsOrder() throws {
        let allowedFields = ["id", "title", "date", "sender"]
        let requested = ["date", "id", "title"]

        let result = try FieldsProjection.validate(requested, allowed: allowedFields)
        #expect(result == ["date", "id", "title"])
    }

    // MARK: - Invalid Fields Tests

    @Test("validateFields throws for invalid field")
    func testInvalidFieldThrows() {
        let allowedFields = ["id", "title", "date"]
        let requested = ["id", "invalid_field"]

        #expect(throws: ValidationError.self) {
            _ = try FieldsProjection.validate(requested, allowed: allowedFields)
        }
    }

    @Test("validateFields error message contains invalid field name")
    func testInvalidFieldErrorMessage() {
        let allowedFields = ["id", "title", "date"]
        let requested = ["foo"]

        do {
            _ = try FieldsProjection.validate(requested, allowed: allowedFields)
            Issue.record("Should have thrown")
        } catch let error as ValidationError {
            #expect(error.userMessage.contains("foo"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("validateFields error message contains valid fields")
    func testInvalidFieldErrorContainsValidFields() {
        let allowedFields = ["id", "title", "date"]
        let requested = ["unknown"]

        do {
            _ = try FieldsProjection.validate(requested, allowed: allowedFields)
            Issue.record("Should have thrown")
        } catch let error as ValidationError {
            // Should list at least some valid fields
            let message = error.userMessage
            #expect(message.contains("id") || message.contains("title") || message.contains("date") || message.lowercased().contains("valid"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("validateFields throws for first invalid field in list")
    func testFirstInvalidField() {
        let allowedFields = ["id", "title", "date"]
        let requested = ["id", "bad1", "bad2"]

        do {
            _ = try FieldsProjection.validate(requested, allowed: allowedFields)
            Issue.record("Should have thrown")
        } catch let error as ValidationError {
            // Should mention one of the bad fields
            #expect(error.userMessage.contains("bad1") || error.userMessage.contains("bad2"))
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    // MARK: - Edge Cases

    @Test("validateFields with empty requested returns empty")
    func testEmptyRequested() throws {
        let allowedFields = ["id", "title", "date"]
        let requested: [String] = []

        let result = try FieldsProjection.validate(requested, allowed: allowedFields)
        #expect(result.isEmpty)
    }

    @Test("validateFields with empty allowed throws for any field")
    func testEmptyAllowedThrows() {
        let allowedFields: [String] = []
        let requested = ["any"]

        #expect(throws: ValidationError.self) {
            _ = try FieldsProjection.validate(requested, allowed: allowedFields)
        }
    }

    @Test("validateFields is case sensitive")
    func testCaseSensitive() {
        let allowedFields = ["id", "Title", "date"]
        let requested = ["title"]  // lowercase 't'

        #expect(throws: ValidationError.self) {
            _ = try FieldsProjection.validate(requested, allowed: allowedFields)
        }
    }

    // MARK: - Deduplication Tests

    @Test("validateFields removes duplicates")
    func testRemovesDuplicates() throws {
        let allowedFields = ["id", "title", "date"]
        let requested = ["id", "title", "id", "title"]

        let result = try FieldsProjection.validate(requested, allowed: allowedFields)
        #expect(result.count == 2)
        #expect(result.contains("id"))
        #expect(result.contains("title"))
    }

    // MARK: - Default Fields Tests

    @Test("validateOrDefault returns requested when valid")
    func testValidateOrDefaultReturnsRequested() throws {
        let allowedFields = ["id", "title", "date"]
        let requested = ["id", "title"]
        let defaultFields = ["id"]

        let result = try FieldsProjection.validateOrDefault(
            requested,
            allowed: allowedFields,
            default: defaultFields
        )
        #expect(result == ["id", "title"])
    }

    @Test("validateOrDefault returns default when empty")
    func testValidateOrDefaultReturnsDefault() throws {
        let allowedFields = ["id", "title", "date"]
        let requested: [String]? = nil
        let defaultFields = ["id", "title"]

        let result = try FieldsProjection.validateOrDefault(
            requested,
            allowed: allowedFields,
            default: defaultFields
        )
        #expect(result == ["id", "title"])
    }

    @Test("validateOrDefault throws for invalid fields even with default")
    func testValidateOrDefaultThrowsForInvalid() {
        let allowedFields = ["id", "title", "date"]
        let requested = ["bad"]
        let defaultFields = ["id"]

        #expect(throws: ValidationError.self) {
            _ = try FieldsProjection.validateOrDefault(
                requested,
                allowed: allowedFields,
                default: defaultFields
            )
        }
    }
}
