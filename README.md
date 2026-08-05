# Apple Bridge

A Swift 6 MCP (Model Context Protocol) server that provides AI assistants with access to macOS applications and services.

## Features

Apple Bridge exposes 7 macOS domains through 35 MCP tools:

| Domain | Tools | Access Method |
|--------|-------|---------------|
| **Reminders** (8) | `reminders_list`, `reminders_get_lists`, `reminders_search`, `reminders_create`, `reminders_update`, `reminders_complete`, `reminders_delete`, `reminders_open` | EventKit |
| **Calendar** (6) | `calendar_list`, `calendar_get`, `calendar_search`, `calendar_create`, `calendar_update`, `calendar_delete` | EventKit |
| **Messages** (5) | `messages_read`, `messages_unread`, `messages_list_chats`, `messages_send`, `messages_schedule` | AppleScript (partial) |
| **Contacts** (4) | `contacts_search`, `contacts_get`, `contacts_me`, `contacts_open` | AppleScript |
| **Notes** (4) | `notes_search`, `notes_get`, `notes_create`, `notes_open` | AppleScript |
| **Mail** (4) | `mail_search`, `mail_unread`, `mail_send`, `mail_compose` | AppleScript |
| **Maps** (4) | `maps_search`, `maps_nearby`, `maps_directions`, `maps_open` | MapKit |

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
| **Automation (Contacts)** | Contacts domain | System Settings → Privacy & Security → Automation |
| **Automation (Notes)** | Notes domain | System Settings → Privacy & Security → Automation |
| **Automation (Messages)** | Messages domain (chats, send) | System Settings → Privacy & Security → Automation |
| **Full Disk Access** | Messages domain (read, unread) | System Settings → Privacy & Security → Full Disk Access |
| **Automation (Mail)** | Mail domain | System Settings → Privacy & Security → Automation |
| **Location Services** | Maps domain | System Settings → Privacy & Security → Location Services |

> **Note:** Messages read/unread requires Full Disk Access because the Messages.app scripting dictionary does not expose individual messages. All other AppleScript domains (Contacts, Notes, Messages chats/send, Mail) only need Automation permission.

### Granting permissions when launched by an MCP host (Claude, etc.)

Apple Bridge is normally launched as a **child process of an MCP host**, and that changes where the
permissions live. Everything below was verified on macOS 15 with Claude Desktop on 2026-08-05.

**1. Grant to the host app, not to `apple-bridge`.** The binary is ad-hoc/linker-signed
(`TeamIdentifier=not set`), so it has no TCC identity of its own and **never appears in System
Settings under its own name**. macOS attributes its requests to the *responsible process* — the host
app at the top of the ancestry chain:

```
apple-bridge → claude (com.anthropic.claude-code) → disclaimer → /Applications/Claude.app
```

So the row to change is **Claude**. Looking for an "apple-bridge" row and concluding the permission
is ungrantable is the most common failure here.

**2. Calendars is a dropdown, not a checkbox.** It defaults to **"Add Events Only"**, which silently
permits `calendar_create` while failing *every read* with `Full Access to Calendars is required to
read events`. Set it to **"Full Access"**. That write-succeeds/read-fails split is easy to misread as
a bug in the bridge.

**3. The row only appears after the first request.** The Calendars/Reminders panes have no "+" button
— rows are created when an app first asks. If the host app is absent from the pane, trigger any
calendar or reminder tool once, then look again.

**4. No prompt does not mean no access.** Host apps that don't declare
`NSCalendarsFullAccessUsageDescription` / `NSRemindersFullAccessUsageDescription` will never show a
permission dialog. The Settings row still works — grant it manually.

**5. A new grant does not reach a running bridge — but you needn't restart the host.** EventKit
caches its authorization verdict at the first request in a process. After changing a setting:

```bash
pkill -f apple-bridge
```

The MCP host respawns the bridge lazily on the next tool call, and the fresh process re-queries TCC.
Note one bridge process runs **per host session**; killing one leaves the others on their stale
cached verdict until they respawn too.

**6. AppleScript-backed domains need the target app running.** Contacts, Notes, Messages, and Mail
are driven via `osascript`, which does **not** auto-launch its target. If the app is closed, the
underlying `-600 "Application isn't running"` currently surfaces as an opaque
`Core.AppleScriptError error 0`. Launch the app (`open -g -a Contacts`) and retry.

### Code signing

`scripts/install.sh` signs every install ad-hoc, which requires no certificate
and binds the embedded `Info.plist` into the signature (SwiftPM's linker-signed
output leaves it unbound, so the privacy usage strings are not covered).

To sign with a Developer ID for distribution to other Macs:

```bash
APPLE_BRIDGE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/install.sh
```

Signing does **not** affect permissions — see [docs/code-signing.md](docs/code-signing.md)
for the certificate, notarization, and what signing does and does not fix.

### Known limitation — AppleScript `whose` searches on large stores

`mail_search` and `notes_search` build AppleScript `whose` queries, which the target app evaluates
with per-item Apple Event round-trips. The cost scales with the store size *and* with how many items
match, so a broad query over a large library cannot finish inside a typical 30-second MCP tool
timeout. Measured on one machine, 2026-08-05:

| Query | Store size | Result |
|---|---|---|
| `mail_search` | ~233,000 messages | times out reliably |
| `notes_search` for `"a"` (matched 1,427 of 2,120) | 2,120 notes | **56 s** via plain `osascript` — over the limit |
| `notes_search` for a specific term | 2,120 notes | returns promptly |

**A timeout here is a scale problem, not a permissions problem** — `mail_unread` and narrow
`notes_search` queries succeed over the identical Automation pathway. Prefer specific search terms,
and use an IMAP-based client for search on very large mailboxes.

### Known limitation — Messages needs Full Disk Access

`messages_read` / `messages_unread` read the Messages SQLite database directly, because Messages.app's
AppleScript dictionary does not expose individual messages. That requires **Full Disk Access**
(System Settings → Privacy & Security → Full Disk Access), granted to the responsible parent app —
the same attribution rule as above. Without it these two tools return an explicit Full-Disk-Access
error rather than an empty result. `messages_send`, `messages_schedule`, and `messages_list_chats`
use AppleScript and need only Automation.

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
2. **Automation access** granted to Terminal/IDE (for Contacts, Notes, Messages, Mail)
3. **Full Disk Access** granted to Terminal/IDE (only for Messages read/unread tests)
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
│  Adapter protocols + Real implementations                       │
│  Uses DTOs (CalendarEventData, NoteData, MessageData, etc.)     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    macOS Frameworks                             │
│  EventKit, AppleScript, MapKit                                  │
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
| **Contacts** | `ContactsAdapterProtocol` | `ContactData` | `AppleScriptContactsAdapter` |
| **Notes** | `NotesAdapterProtocol` | `NoteData`, `NoteFolderData` | `AppleScriptNotesAdapter` |
| **Messages** | `MessagesAdapterProtocol` | `MessageData`, `ChatData` | `AppleScriptMessagesAdapter` |
| **Mail** | `MailAdapterProtocol` | `EmailData`, `MailboxData` | `AppleScriptMailAdapter` |
| **Maps** | `MapsAdapterProtocol` | `LocationData` | `MapKitAdapter` |

#### Read/Write Technology by Domain

| Domain | Read | Write | Adapter |
|--------|------|-------|---------|
| Calendar | EventKit | EventKit | `EventKitAdapter` |
| Reminders | EventKit | EventKit | `EventKitAdapter` |
| Contacts | AppleScript | Read-only | `AppleScriptContactsAdapter` |
| Notes | AppleScript | AppleScript | `AppleScriptNotesAdapter` |
| Messages | AppleScript (chats only) | AppleScript | `AppleScriptMessagesAdapter` |
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
│   ├── ContactsAdapter.swift            # Contacts framework implementation (requires signed binary)
│   ├── AppleScriptContactsAdapter.swift # AppleScript implementation (default)
│   └── ContactsFrameworkService.swift   # ContactsService using adapter
├── NotesAdapter/
│   ├── NotesAdapterProtocol.swift       # Protocol + NoteData DTO
│   ├── SQLiteNotesAdapter.swift         # SQLite implementation (requires Full Disk Access)
│   └── AppleScriptNotesAdapter.swift    # AppleScript implementation (default)
├── MessagesAdapter/
│   ├── MessagesAdapterProtocol.swift    # Protocol + MessageData/ChatData DTOs
│   ├── HybridMessagesAdapter.swift      # SQLite (read) + AppleScript (send) (requires FDA)
│   └── AppleScriptMessagesAdapter.swift # AppleScript implementation (default, partial)
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

**"Permission denied" for Calendar/Reminders:**
1. Open System Settings → Privacy & Security
2. Find the relevant section (Calendars or Reminders)
3. Enable access for your terminal application or Claude Desktop

**"AppleScript error" for Contacts/Notes/Messages/Mail:**
1. Open System Settings → Privacy & Security → Automation
2. Enable access to the relevant app (Contacts.app, Notes.app, Messages.app, Mail.app)
3. You may need to run a command once to trigger the permission prompt

**"Full Disk Access required" for Messages read/unread:**
The Messages.app scripting dictionary does not expose individual messages, so reading message history requires direct database access via Full Disk Access:
1. Open System Settings → Privacy & Security → Full Disk Access
2. Add the `apple-bridge` executable (requires a properly signed binary)
3. Restart the application after granting access

> **Note:** Ad-hoc signed binaries cannot reliably hold Full Disk Access TCC entries. A signed binary (Apple Developer certificate) is required for Messages read/unread functionality.

### Common Issues

**Server doesn't respond:**
- Ensure you're using the correct path to the `apple-bridge` executable
- Check that the executable has execute permissions: `chmod +x apple-bridge`
- Verify no other process is using stdin/stdout

**Tool returns empty results:**
- Verify the relevant macOS app has data (e.g., Calendar has events)
- Check that permissions are granted in System Settings

**Mail operations are slow or time out:**
- Mail uses indexed reverse iteration to avoid loading all messages at once
- Very large inboxes (100K+ messages) may still take a few seconds for search
- Ensure Mail.app is not in an unresponsive state

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
