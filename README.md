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
| **Maps** | `maps_search`, `maps_directions`, `maps_guides` | AppleScript + URL Schemes |

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
| **Automation (Maps)** | Maps domain | System Settings → Privacy & Security → Automation |

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
│   ├── Core/               # Domain models and protocols
│   ├── Adapters/           # macOS framework adapters
│   └── MCPServer/          # MCP protocol implementation
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

### Swift 6 Concurrency

Apple Bridge is fully Swift 6 compliant with strict concurrency checking:

- All service protocols are `Sendable`
- Adapters use actors where needed for thread safety
- No data races or Sendable violations

### Error Handling

Errors follow a consistent pattern:

- `ToolError` for MCP-level errors (invalid arguments, unknown tool)
- `ServiceError` for domain-level errors (permission denied, not found)
- All errors include remediation instructions when applicable

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
