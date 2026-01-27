import Testing
import MCP
@testable import MCPServer
import TestUtilities

@Suite("ToolDispatcher Tests")
struct ToolDispatcherTests {

    // MARK: - Basic Dispatch Tests

    @Test("Dispatcher handles unknown tool with UNKNOWN_TOOL error")
    func testDispatcherHandlesUnknownTool() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)
        let dispatcher = ToolDispatcher(registry: registry)

        let result = await dispatcher.dispatch(name: "nonexistent_tool", arguments: nil)

        #expect(result.isError == true)

        let hasUnknownToolError = result.content.contains { content in
            if case .text(let text) = content {
                return text.contains("UNKNOWN_TOOL")
            }
            return false
        }
        #expect(hasUnknownToolError, "Expected UNKNOWN_TOOL error message")
    }

    @Test("Dispatcher successfully dispatches known tool")
    func testDispatcherDispatchesKnownTool() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)
        let dispatcher = ToolDispatcher(registry: registry)

        // All tools return NOT_IMPLEMENTED in Phase 4
        let result = await dispatcher.dispatch(name: "calendar_list", arguments: nil)

        #expect(result.isError == true)

        let hasNotImplemented = result.content.contains { content in
            if case .text(let text) = content {
                return text.contains("NOT_IMPLEMENTED")
            }
            return false
        }
        #expect(hasNotImplemented, "Expected NOT_IMPLEMENTED for stub tool")
    }

    // MARK: - Timeout Tests

    @Test("Dispatcher handles timeout when tool exceeds time limit")
    func testDispatcherHandlesTimeout() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        // Set a custom handler that sleeps longer than timeout
        await registry.setHandler(for: "calendar_list") { _ in
            // Sleep for 2 seconds
            try? await Task.sleep(for: .seconds(2))
            return CallTool.Result(content: [.text("Success")], isError: false)
        }

        // Create dispatcher with 100ms timeout
        let dispatcher = ToolDispatcher(registry: registry, timeout: .milliseconds(100))

        let result = await dispatcher.dispatch(name: "calendar_list", arguments: nil)

        #expect(result.isError == true)

        let hasTimeoutError = result.content.contains { content in
            if case .text(let text) = content {
                return text.contains("TIMEOUT") || text.contains("timed out")
            }
            return false
        }
        #expect(hasTimeoutError, "Expected timeout error message")
    }

    @Test("Dispatcher completes within timeout when tool is fast")
    func testDispatcherCompletesWithinTimeout() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        // Set a fast handler
        await registry.setHandler(for: "calendar_list") { _ in
            CallTool.Result(content: [.text("Fast response")], isError: false)
        }

        let dispatcher = ToolDispatcher(registry: registry, timeout: .seconds(5))

        let result = await dispatcher.dispatch(name: "calendar_list", arguments: nil)

        #expect(result.isError == false)

        let hasExpectedContent = result.content.contains { content in
            if case .text(let text) = content {
                return text.contains("Fast response")
            }
            return false
        }
        #expect(hasExpectedContent, "Expected 'Fast response' in result")
    }

    // MARK: - Argument Passing Tests

    @Test("Dispatcher passes arguments to tool handler")
    func testDispatcherPassesArguments() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)

        // Use actor to safely capture arguments
        actor ArgsCapture {
            var args: [String: Value]?
            func capture(_ value: [String: Value]?) { args = value }
            func get() -> [String: Value]? { args }
        }

        let capture = ArgsCapture()

        await registry.setHandler(for: "calendar_search") { args in
            await capture.capture(args)
            return CallTool.Result(content: [.text("OK")], isError: false)
        }

        let dispatcher = ToolDispatcher(registry: registry)
        let args: [String: Value] = ["query": .string("meeting"), "limit": .int(10)]

        _ = await dispatcher.dispatch(name: "calendar_search", arguments: args)

        let receivedArgs = await capture.get()
        #expect(receivedArgs != nil)
        #expect(receivedArgs?["query"]?.stringValue == "meeting")
        #expect(receivedArgs?["limit"]?.intValue == 10)
    }
}
