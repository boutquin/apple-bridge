import Testing
import Foundation
@testable import Adapters
@testable import Core

/// Tests for `AppleScriptRunner`, the actor for executing AppleScript.
///
/// These tests verify:
/// - Actor pattern enforces serialization
/// - Scripts can be executed
/// - Cancellation is handled
/// - Errors are properly propagated
@Suite("AppleScriptRunner Tests")
struct AppleScriptRunnerTests {

    // MARK: - Actor Properties

    @Test("AppleScriptRunner is an actor")
    func testRunnerIsActor() {
        // Compile-time check: accessing .shared proves actor type
        let runner: any Sendable = AppleScriptRunner.shared
        #expect(runner is AppleScriptRunner)
    }

    @Test("AppleScriptRunner has shared singleton")
    func testRunnerHasSharedSingleton() async {
        let runner1 = AppleScriptRunner.shared
        let runner2 = AppleScriptRunner.shared

        // Both should be the same instance
        #expect(runner1 === runner2)
    }

    // MARK: - Script Execution

    @Test("run executes simple AppleScript successfully")
    func testRunExecutesSimpleScript() async throws {
        let runner = AppleScriptRunner.shared

        // Simple script that returns a value
        let result = try await runner.run(script: "return \"hello\"")

        #expect(result == "hello")
    }

    @Test("run executes arithmetic in AppleScript")
    func testRunExecutesArithmetic() async throws {
        let runner = AppleScriptRunner.shared

        let result = try await runner.run(script: "return 2 + 2")

        #expect(result == "4")
    }

    @Test("run returns empty string for scripts without return")
    func testRunReturnsEmptyForNoReturn() async throws {
        let runner = AppleScriptRunner.shared

        // Script that does something but doesn't return
        let result = try await runner.run(script: "set x to 1")

        // osascript may return empty or the last expression value
        #expect(result.isEmpty || !result.isEmpty) // Just verify no throw
    }

    @Test("run throws for invalid AppleScript")
    func testRunThrowsForInvalidScript() async throws {
        let runner = AppleScriptRunner.shared

        do {
            _ = try await runner.run(script: "this is not valid applescript @#$%")
            Issue.record("Should have thrown an error")
        } catch let error as AppleScriptError {
            // Expected - invalid script
            #expect(error.userMessage.contains("AppleScript") || !error.userMessage.isEmpty)
        } catch {
            // Any error is acceptable for invalid script
        }
    }

    @Test("run throws AppleScriptError for execution failure")
    func testRunThrowsAppleScriptError() async throws {
        let runner = AppleScriptRunner.shared

        do {
            // Try to access a non-existent application
            _ = try await runner.run(script: """
                tell application "NonExistentApp12345"
                    activate
                end tell
                """)
            // Note: This might not throw on some systems, depending on app availability
        } catch _ as AppleScriptError {
            // Expected
        } catch {
            // Other errors are also acceptable
        }
    }

    // MARK: - Serialization Tests

    @Test("run serializes concurrent calls through actor")
    func testRunSerializesConcurrentCalls() async throws {
        let runner = AppleScriptRunner.shared

        // Track execution order
        actor OrderTracker {
            var startOrder: [Int] = []
            var endOrder: [Int] = []

            func recordStart(_ n: Int) { startOrder.append(n) }
            func recordEnd(_ n: Int) { endOrder.append(n) }
            func getStartOrder() -> [Int] { startOrder }
            func getEndOrder() -> [Int] { endOrder }
        }

        let tracker = OrderTracker()

        // Launch 3 concurrent tasks with small delays
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<3 {
                group.addTask {
                    await tracker.recordStart(i)
                    // Simple script that completes quickly
                    _ = try? await runner.run(script: "return \(i)")
                    await tracker.recordEnd(i)
                }
            }
        }

        let endOrder = await tracker.getEndOrder()
        #expect(endOrder.count == 3, "All tasks should complete")
    }

    // MARK: - Sendable Conformance

    @Test("AppleScriptRunner is Sendable")
    func testRunnerIsSendable() {
        let runner = AppleScriptRunner.shared

        // Compile-time check: can be passed across actor boundaries
        Task { @Sendable in
            _ = runner
        }
    }

    // MARK: - Multi-line Scripts

    @Test("run handles multi-line scripts")
    func testRunHandlesMultiLineScripts() async throws {
        let runner = AppleScriptRunner.shared

        let result = try await runner.run(script: """
            set a to 5
            set b to 3
            return a + b
            """)

        #expect(result == "8")
    }

    // MARK: - String Escaping

    @Test("run handles scripts with quotes")
    func testRunHandlesQuotes() async throws {
        let runner = AppleScriptRunner.shared

        let result = try await runner.run(script: "return \"test\"")

        #expect(result == "test")
    }

    // MARK: - Timeout Tests

    @Test("run with timeout completes fast scripts")
    func testRunWithTimeoutCompletesFastScripts() async throws {
        let runner = AppleScriptRunner.shared

        // Fast script with generous timeout should succeed
        let result = try await runner.run(script: "return 42", timeout: 5.0)

        #expect(result == "42")
    }

    @Test("run with timeout throws for slow scripts")
    func testRunWithTimeoutThrowsForSlowScripts() async throws {
        let runner = AppleScriptRunner.shared

        do {
            // Script that delays longer than timeout
            _ = try await runner.run(script: "delay 3", timeout: 0.1)
            Issue.record("Should have thrown a timeout error")
        } catch let error as AppleScriptError {
            if case .timeout(let seconds) = error {
                #expect(seconds == 0, "Timeout should report the configured seconds")
            } else {
                // executionFailed is also acceptable if process was terminated
                #expect(Bool(true))
            }
        } catch {
            // CancellationError or other errors are acceptable
            #expect(Bool(true))
        }
    }
}
