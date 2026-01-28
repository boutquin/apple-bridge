# Apple Bridge

A Swift 6 MCP (Model Context Protocol) server that provides AI assistants with access to macOS applications and services.

## Features

Apple Bridge exposes 7 macOS domains through MCP tools:

| Domain | Tools | Access Method |
|--------|-------|---------------|
| **Calendar** | `calendar_list`, `calendar_create`, `calendar_update`, `calendar_delete` | EventKit |
| **Reminders** | `reminders_list`, `reminders_create`, `reminders_update`, `reminders_complete`, `reminders_delete` | EventKit |
| **Contacts** | `contacts_search`, `contacts_me` | Contacts Framework |
| **Notes** | `notes_search`, `notes_list`, `notes_create` | SQLite (Full Disk Access) |
| **Messages** | `messages_read`, `messages_send`, `messages_unread` | SQLite (Full Disk Access) |
| **Mail** | `mail_search`, `mail_unread`, `mail_send` | AppleScript |
| **Maps** | `maps_search`, `maps_nearby`, `maps_directions`, `maps_open` | MapKit |

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 6.0+
- Xcode 16.0+ (for development)

## Installation

```bash
git clone https://github.com/boutquin/apple-bridge.git
cd apple-bridge
swift build -c release
```

The executable will be at `.build/release/apple-bridge`.

## Permissions

Apple Bridge requires various macOS permissions depending on which domains you use:

| Permission | Required For | Grant Location |
|------------|--------------|----------------|
| **Calendar** | Calendar domain | System Settings → Privacy & Security → Calendars |
| **Reminders** | Reminders domain | System Settings → Privacy & Security → Reminders |
| **Contacts** | Contacts domain | System Settings → Privacy & Security → Contacts |
| **Full Disk Access** | Notes, Messages | System Settings → Privacy & Security → Full Disk Access |
| **Automation (Mail)** | Mail domain | System Settings → Privacy & Security → Automation |
| **Location Services** | Maps domain | System Settings → Privacy & Security → Location Services |

## Usage with Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "apple-bridge": {
      "command": "/path/to/apple-bridge"
    }
  }
}
```

## Development

### Building

```bash
swift build           # Debug build
swift build -c release # Release build
```

### Testing

Apple Bridge has several test categories:

```bash
# Run all unit tests (no permissions required)
swift test

# Run specific test suites
swift test --filter CoreTests
swift test --filter AdapterTests
swift test --filter MCPServerTests
swift test --filter E2ETests
```

### System Tests

System tests verify real macOS integration and require proper permissions. They are **disabled by default** to allow CI to pass without macOS permissions.

#### Running System Tests Locally

```bash
# Enable and run system tests
export APPLE_BRIDGE_SYSTEM_TESTS=1
swift test --filter SystemTests

# Or use the convenience script
./scripts/run-system-tests.sh

# With coverage reporting
./scripts/run-system-tests.sh --coverage
```

#### Prerequisites for System Tests

Before running system tests, ensure:

1. **Calendar access** granted to Terminal/IDE
2. **Contacts access** granted to Terminal/IDE
3. **Full Disk Access** granted to Terminal/IDE (for Notes/Messages)
4. **Apple Mail** configured with at least one account
5. **Apple Maps** available

#### Manual QA Tests (FDA Degradation)

Some tests verify graceful degradation when permissions are denied. These require special setup:

```bash
# 1. REMOVE Full Disk Access from the apple-bridge binary
# 2. Set both environment variables
export APPLE_BRIDGE_SYSTEM_TESTS=1
export APPLE_BRIDGE_MANUAL_QA=1

# 3. Run FDA tests
swift test --filter FDA

# 4. Re-grant Full Disk Access after testing
```

### Project Structure

```
apple-bridge/
├── Sources/
│   ├── apple-bridge/       # Main executable
│   ├── Core/               # Domain models, service protocols, errors
│   ├── Adapters/           # macOS framework adapters (see Architecture)
│   └── MCPServer/          # MCP protocol implementation and handlers
├── Tests/
│   ├── CoreTests/          # Unit tests for Core
│   ├── AdapterTests/       # Unit tests for Adapters
│   ├── MCPServerTests/     # Unit tests for MCP handlers
│   ├── E2ETests/           # End-to-end protocol tests
│   ├── SystemTests/        # Real macOS integration tests
│   └── TestUtilities/      # Shared test helpers
└── scripts/
    └── run-system-tests.sh # System test runner
```

### Test Utilities

The `TestUtilities` module provides shared testing infrastructure:

- **Factory Functions**: `makeTestEvent()`, `makeTestReminder()`, etc.
- **Mock Services**: `MockCalendarService`, `MockNotesService`, etc.
- **ProcessRunner**: Shared executable runner for E2E and System tests

## Architecture

### Three-Layer Architecture

Apple Bridge uses a clean three-layer architecture that separates concerns and enables comprehensive testing:

```
┌─────────────────────────────────────────────────────────────────┐
│                        MCP Handlers                             │
│  (MCPServer/Handlers/)                                          │
│  Receives MCP tool calls, validates arguments, returns JSON     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Service Layer                              │
│  (Core/Services/)                                               │
│  Domain protocols (CalendarService, NotesService, etc.)         │
│  Uses domain models (CalendarEvent, Note, Message, etc.)        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Adapter Layer                              │
│  (Adapters/)                                                    │
│  Adapter protocols + Real implementations                        │
│  Uses DTOs (CalendarEventData, NoteData, MessageData, etc.)     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    macOS Frameworks                             │
│  EventKit, Contacts, SQLite, AppleScript                        │
└─────────────────────────────────────────────────────────────────┘
```

### Adapter Pattern

Each domain uses the **Adapter Pattern** to decouple the service layer from specific macOS framework implementations. This provides:

1. **Testability**: Mock adapters can be injected for unit testing without macOS permissions
2. **Flexibility**: Alternative implementations can be swapped (e.g., MapKit vs AppleScript for Maps)
3. **Clean Boundaries**: DTOs provide Sendable-safe data transfer across actor boundaries
4. **Implementation Hiding**: Service layer doesn't know if data comes from SQLite, EventKit, or AppleScript

#### Adapter Protocols by Domain

| Domain | Adapter Protocol | DTOs | Implementation |
|--------|------------------|------|----------------|
| **Calendar** | `CalendarAdapterProtocol` | `CalendarEventData`, `CalendarData` | `EventKitAdapter` |
| **Reminders** | `CalendarAdapterProtocol` | `ReminderData`, `ReminderListData` | `EventKitAdapter` |
| **Contacts** | `ContactsAdapterProtocol` | `ContactData` | `ContactsAdapter` |
| **Notes** | `NotesAdapterProtocol` | `NoteData`, `NoteFolderData` | `SQLiteNotesAdapter` |
| **Messages** | `MessagesAdapterProtocol` | `MessageData`, `ChatData` | `HybridMessagesAdapter` |
| **Mail** | `MailAdapterProtocol` | `EmailData`, `MailboxData` | `AppleScriptMailAdapter` |
| **Maps** | `MapsAdapterProtocol` | `LocationData` | `MapKitAdapter` |

#### Read/Write Technology by Domain

| Domain | Read | Write | Adapter |
|--------|------|-------|---------|
| Calendar | EventKit | EventKit | `EventKitAdapter` |
| Reminders | EventKit | EventKit | `EventKitAdapter` |
| Contacts | Contacts framework | Contacts framework | `ContactsAdapter` |
| Notes | SQLite | SQLite | `SQLiteNotesAdapter` |
| Messages | SQLite | AppleScript | `HybridMessagesAdapter` |
| Mail | AppleScript | AppleScript | `AppleScriptMailAdapter` |
| Maps | MapKit | MapKit | `MapKitAdapter` |

#### DTO Design Principles

Data Transfer Objects (DTOs) follow these principles:

- **Sendable**: All DTOs are `Sendable` for safe actor boundary crossing
- **Codable**: DTOs are `Codable` for serialization when needed
- **Equatable**: DTOs are `Equatable` for testing assertions
- **Implementation-Agnostic**: No framework-specific prefixes (e.g., `CalendarEventData` not `EKEventData`)
- **Lightweight**: Only essential fields, no framework dependencies

Example DTO:

```swift
public struct CalendarEventData: Sendable, Equatable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let calendarId: String
    public let location: String?
    public let notes: String?
}
```

#### Service-to-Adapter Flow

Services delegate to adapters and convert between domain models and DTOs:

```swift
// Service implementation
public struct NotesSQLiteService: NotesService {
    private let adapter: any NotesAdapterProtocol

    public func get(id: String) async throws -> Note {
        let noteData = try await adapter.fetchNote(id: id)
        return toNote(noteData)  // Convert DTO to domain model
    }

    private func toNote(_ data: NoteData) -> Note {
        Note(id: data.id, title: data.title, body: data.body, ...)
    }
}
```

#### Mock Adapters for Testing

Each domain has a corresponding mock adapter for unit testing:

| Domain | Mock Adapter | Location |
|--------|--------------|----------|
| Calendar/Reminders | `MockEventKitAdapter` | `Tests/AdapterTests/Mocks/` |
| Contacts | `MockContactsAdapter` | `Tests/AdapterTests/Mocks/` |
| Notes | `MockNotesAdapter` | `Tests/AdapterTests/Mocks/` |
| Messages | `MockMessagesAdapter` | `Tests/AdapterTests/Mocks/` |
| Mail | `MockMailAdapter` | `Tests/AdapterTests/Mocks/` |
| Maps | `MockMapsAdapter` | `Tests/AdapterTests/Mocks/` |

Mock adapters are actors that:
- Store stubbed data for return values
- Track method calls for verification
- Allow error injection for testing error paths

Example usage:

```swift
func testSearchNotes() async throws {
    let mockAdapter = MockNotesAdapter()
    await mockAdapter.setStubNotes([
        NoteData(id: "1", title: "Meeting Notes", body: "...", modifiedAt: "...")
    ])

    let service = NotesSQLiteService(adapter: mockAdapter)
    let results = try await service.search(query: "Meeting", limit: 10, includeBody: true)

    XCTAssertEqual(results.items.count, 1)
    XCTAssertEqual(results.items[0].title, "Meeting Notes")
}
```

### Adapter File Locations

```
Sources/Adapters/
├── EventKitAdapter/
│   ├── CalendarAdapterProtocol.swift    # Protocol + Calendar/Reminder DTOs
│   ├── EventKitAdapter.swift            # EventKit implementation
│   ├── EventKitCalendarService.swift    # CalendarService using adapter
│   └── EventKitRemindersService.swift   # RemindersService using adapter
├── ContactsAdapter/
│   ├── ContactsAdapterProtocol.swift    # Protocol + ContactData DTO
│   ├── ContactsAdapter.swift            # Contacts framework implementation
│   └── ContactsFrameworkService.swift   # ContactsService using adapter
├── NotesAdapter/
│   ├── NotesAdapterProtocol.swift       # Protocol + NoteData DTO
│   └── SQLiteNotesAdapter.swift         # SQLite implementation
├── MessagesAdapter/
│   ├── MessagesAdapterProtocol.swift    # Protocol + MessageData/ChatData DTOs
│   └── HybridMessagesAdapter.swift      # SQLite (read) + AppleScript (send) implementation
├── MailAdapter/
│   ├── MailAdapterProtocol.swift        # Protocol + EmailData DTO
│   └── AppleScriptMailAdapter.swift     # AppleScript implementation
├── MapsAdapter/
│   ├── MapsAdapterProtocol.swift        # Protocol + LocationData DTO
│   ├── MapKitAdapter.swift              # MapKit implementation
│   └── MapsKitService.swift             # MapsService using MapKitAdapter
├── SQLiteAdapter/
│   ├── SQLiteConnection.swift           # Low-level SQLite wrapper
│   ├── SchemaValidation.swift           # Database schema validation
│   ├── NotesSQLiteService.swift         # NotesService using NotesAdapter
│   └── MessagesSQLiteService.swift      # MessagesService using MessagesAdapter
└── AppleScriptAdapter/
    ├── AppleScriptRunner.swift          # Actor for script execution
    └── MailAppleScriptService.swift     # MailService using MailAdapter
```

### Swift 6 Concurrency

Apple Bridge is fully Swift 6 compliant with strict concurrency checking:

- All service protocols are `Sendable`
- All adapter protocols are `Sendable`
- All DTOs are `Sendable`
- Adapters use actors where needed for thread safety
- No data races or Sendable violations

### Error Handling

Errors follow a consistent pattern:

- `ToolError` for MCP-level errors (invalid arguments, unknown tool)
- `ValidationError` for domain validation (not found, missing required fields)
- `PermissionError` for access issues (calendar denied, full disk access required)
- `AppleScriptError` for AppleScript execution failures
- `SQLiteError` for database errors

All errors include remediation instructions when applicable.

### MCP Protocol

Apple Bridge implements MCP specification 2024-11-05:

- JSON-RPC 2.0 over stdio
- Tool definitions with JSON Schema validation
- Cursor-based pagination for list operations

## Troubleshooting

### Permission Denied Errors

**"Permission denied" for Calendar/Reminders/Contacts:**
1. Open System Settings → Privacy & Security
2. Find the relevant section (Calendars, Reminders, or Contacts)
3. Enable access for your terminal application or Claude Desktop

**"Unable to access database" for Notes/Messages:**
1. Open System Settings → Privacy & Security → Full Disk Access
2. Add your terminal application or the `apple-bridge` executable
3. Restart the application after granting access

**"AppleScript error" for Mail/Maps:**
1. Open System Settings → Privacy & Security → Automation
2. Enable access to Mail.app and/or Maps.app for your terminal
3. You may need to run a command once to trigger the permission prompt

### Common Issues

**Server doesn't respond:**
- Ensure you're using the correct path to the `apple-bridge` executable
- Check that the executable has execute permissions: `chmod +x apple-bridge`
- Verify no other process is using stdin/stdout

**Tool returns empty results:**
- Verify the relevant macOS app has data (e.g., Calendar has events)
- Check that permissions are granted in System Settings
- For Notes/Messages, ensure Full Disk Access is enabled

**Tests fail with permission errors:**
- Unit tests don't require permissions and should always pass
- System tests require `APPLE_BRIDGE_SYSTEM_TESTS=1` and proper permissions
- See the "System Tests" section above for setup instructions

### Debug Mode

To see detailed logging, run with stderr visible:

```bash
# View logs while running
./apple-bridge 2>apple-bridge.log &
tail -f apple-bridge.log
```

Logs go to stderr only; stdout is reserved for MCP protocol messages.

## CI Status

[![CI](https://github.com/boutquin/apple-bridge/actions/workflows/ci.yml/badge.svg)](https://github.com/boutquin/apple-bridge/actions/workflows/ci.yml)

## License

MIT License - see LICENSE file for details.
