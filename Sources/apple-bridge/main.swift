import Foundation
import MCP
import Core
import Adapters
import MCPServer

/// The apple-bridge MCP server version.
let serverVersion = "3.0.8"

/// Global reference to the server for signal handling.
/// This is necessary because C signal handlers cannot capture Swift closures.
/// The `nonisolated(unsafe)` is required because signal handlers run in a C context
/// outside of Swift's structured concurrency model.
nonisolated(unsafe) private var globalServer: Server?

/// Signal handler for SIGINT and SIGTERM.
private func handleSignal(_ signal: Int32) {
    guard let server = globalServer else { return }
    Task {
        await server.stop()
    }
}

/// Main entry point for the apple-bridge MCP server.
///
/// The server communicates via stdin/stdout using the JSON-RPC protocol
/// as defined by the Model Context Protocol (MCP) specification.
@main
struct AppleBridge {

    static func main() async throws {
        // Create production services
        let services = createProductionServices()

        // Create tool registry and dispatcher
        let registry = ToolRegistry.create(services: services)
        let dispatcher = ToolDispatcher(registry: registry, timeout: .seconds(30))

        // Create and configure MCP server
        let server = Server(
            name: "apple-bridge",
            version: serverVersion,
            capabilities: Server.Capabilities(
                tools: .init(listChanged: false)
            )
        )

        // Store global reference for signal handling
        globalServer = server

        // Register tools/list handler
        _ = await server.withMethodHandler(ListTools.self) { _ in
            let tools = await dispatcher.definitions
            return ListTools.Result(tools: tools, nextCursor: nil)
        }

        // Register tools/call handler
        _ = await server.withMethodHandler(CallTool.self) { params in
            let result = await dispatcher.dispatch(name: params.name, arguments: params.arguments)
            return result
        }

        // Set up signal handling for graceful shutdown
        setupSignalHandling()

        // Start server with stdio transport
        let transport = StdioTransport()
        try await server.start(transport: transport)

        // Wait for server to complete
        await server.waitUntilCompleted()

        // Clean up global reference
        globalServer = nil
    }

    /// Creates the production services container with real implementations.
    private static func createProductionServices() -> AppleServices {
        // EventKit-based services
        let eventKitAdapter = RealEventKitAdapter()
        let calendarService = EventKitCalendarService(adapter: eventKitAdapter)
        let remindersService = EventKitRemindersService(adapter: eventKitAdapter)

        // Contacts framework service
        let contactsAdapter = RealContactsAdapter()
        let contactsService = ContactsFrameworkService(adapter: contactsAdapter)

        // SQLite-based services
        let notesService = NotesSQLiteService()
        let messagesService = MessagesSQLiteService()

        // AppleScript-based services
        let mailService = MailAppleScriptService()

        // MapKit-based services (for real location data)
        let mapsService = MapsKitService()

        return AppleServices(
            calendar: calendarService,
            reminders: remindersService,
            contacts: contactsService,
            notes: notesService,
            messages: messagesService,
            mail: mailService,
            maps: mapsService
        )
    }

    /// Sets up signal handling for graceful shutdown.
    private static func setupSignalHandling() {
        // Handle SIGINT (Ctrl+C)
        signal(SIGINT, handleSignal)

        // Handle SIGTERM
        signal(SIGTERM, handleSignal)
    }
}
