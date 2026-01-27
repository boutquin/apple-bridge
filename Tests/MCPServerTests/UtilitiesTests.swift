import Testing
import Core
@testable import MCPServer

@Suite("Utilities Tests")
struct UtilitiesTests {

    // MARK: - Timeout Wrapper Tests

    @Test("withTimeout returns value when operation succeeds within time limit")
    func testTimeoutWrapperSucceeds() async throws {
        let result = try await withTimeout(duration: .seconds(5)) {
            return "success"
        }

        #expect(result == "success")
    }

    @Test("withTimeout throws ToolError.deadlineExceeded when operation exceeds time limit")
    func testTimeoutWrapperTimesOut() async throws {
        do {
            _ = try await withTimeout(duration: .milliseconds(50)) {
                try await Task.sleep(for: .seconds(2))
                return "should not reach"
            }
            #expect(Bool(false), "Expected timeout error to be thrown")
        } catch let error as ToolError {
            switch error {
            case .deadlineExceeded:
                // Expected
                break
            default:
                #expect(Bool(false), "Expected ToolError.deadlineExceeded, got \(error)")
            }
        } catch {
            #expect(Bool(false), "Expected ToolError, got \(type(of: error)): \(error)")
        }
    }

    @Test("withTimeout throws when timeout occurs before operation completes")
    func testTimeoutWrapperThrowsOnTimeout() async throws {
        // Verify that the timeout throws the expected error and doesn't hang
        var didThrow = false
        do {
            _ = try await withTimeout(duration: .milliseconds(50)) {
                try await Task.sleep(for: .seconds(10))
                return "should not reach"
            }
        } catch is ToolError {
            didThrow = true
        }

        #expect(didThrow == true, "Should throw ToolError when timeout occurs")
    }

    @Test("withTimeout propagates errors from operation")
    func testTimeoutWrapperPropagatesErrors() async throws {
        struct TestError: Error {}

        do {
            _ = try await withTimeout(duration: .seconds(5)) {
                throw TestError()
            }
            #expect(Bool(false), "Expected TestError to be thrown")
        } catch is TestError {
            // Expected
        } catch {
            #expect(Bool(false), "Expected TestError, got \(type(of: error))")
        }
    }

    @Test("withTimeout works with various return types")
    func testTimeoutWrapperVariousTypes() async throws {
        // Int
        let intResult = try await withTimeout(duration: .seconds(1)) { 42 }
        #expect(intResult == 42)

        // Array
        let arrayResult = try await withTimeout(duration: .seconds(1)) { [1, 2, 3] }
        #expect(arrayResult == [1, 2, 3])

        // Optional
        let optionalResult: String? = try await withTimeout(duration: .seconds(1)) { nil }
        #expect(optionalResult == nil)

        // Struct
        struct Data: Equatable { let value: Int }
        let structResult = try await withTimeout(duration: .seconds(1)) { Data(value: 5) }
        #expect(structResult == Data(value: 5))
    }
}
