import Foundation
import MCP
import Core
import Adapters
import MCPServer

/// The apple-bridge MCP server version.
let serverVersion = "3.0.15"

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
        // Request permissions at startup unless APPLE_BRIDGE_SKIP_PERMISSIONS is set.
        // E2E tests set this to avoid blocking on TCC prompts in headless environments.
        let skipPermissions = ProcessInfo.processInfo.environment["APPLE_BRIDGE_SKIP_PERMISSIONS"] != nil

        let eventKitAdapter = EventKitAdapter()

        if !skipPermissions {
            // Request EventKit permissions before creating services.
            // On macOS 14+, calendar access is split into writeOnly vs fullAccess.
            // Without explicitly requesting fullAccess, reads return empty results
            // even though writes succeed — making calendar tools non-functional.
            let calendarGranted = try await eventKitAdapter.requestCalendarAccess()
            let remindersGranted = try await eventKitAdapter.requestRemindersAccess()

            if !calendarGranted {
                FileHandle.standardError.write(
                    Data("[apple-bridge] WARNING: Calendar access not granted. Calendar tools will not work. Grant Full Access in System Settings → Privacy & Security → Calendars.\n".utf8)
                )
            }
            if !remindersGranted {
                FileHandle.standardError.write(
                    Data("[apple-bridge] WARNING: Reminders access not granted. Reminder tools will not work. Grant access in System Settings → Privacy & Security → Reminders.\n".utf8)
                )
            }

            // Contacts uses AppleScript via Contacts.app — no CNContactStore TCC needed.
            // Probe to check if Automation permission is granted.
            let contactsAdapter = AppleScriptContactsAdapter()
            let contactsGranted = try await contactsAdapter.requestAccess()
            if !contactsGranted {
                FileHandle.standardError.write(
                    Data("[apple-bridge] WARNING: Contacts access not granted. Contacts tools may not work. Grant Automation permission for apple-bridge to control Contacts in System Settings → Privacy & Security → Automation.\n".utf8)
                )
            }
        }

        // Create production services (reuses adapters that already have permissions)
        let services = createProductionServices(eventKitAdapter: eventKitAdapter)

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
    /// - Parameter eventKitAdapter: The pre-authorized EventKit adapter (permissions already requested at startup).
    private static func createProductionServices(eventKitAdapter: EventKitAdapter) -> AppleServices {
        // EventKit-based services (adapter passed in with permissions already granted)
        let calendarService = EventKitCalendarService(adapter: eventKitAdapter)
        let remindersService = EventKitRemindersService(adapter: eventKitAdapter)

        // Contacts via AppleScript (bypasses CNContactStore TCC issues with ad-hoc signed binaries)
        let contactsService = ContactsFrameworkService(adapter: AppleScriptContactsAdapter())

        // Notes and Messages via AppleScript (bypasses Full Disk Access TCC issues with ad-hoc signed binaries)
        // Note: Messages read/unread still require FDA — AppleScript dictionary has no message class
        let notesService = NotesSQLiteService(adapter: AppleScriptNotesAdapter())
        let messagesService = MessagesSQLiteService(adapter: AppleScriptMessagesAdapter())

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
