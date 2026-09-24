# Changelog

All notable changes to apple-bridge are recorded here. Versions follow
[Semantic Versioning](https://semver.org/); the number is single-sourced in
`Sources/Core/Version.swift` and mirrored into `Info.plist`. Since 3.2.0 the
number also covers the public API of the library products: a breaking change
to them is a major version.

## [3.2.0] — 2026-09-24

### Added

- Library products for building on apple-bridge from another Swift package:

  | Product | Module | Contents |
  |---|---|---|
  | `AppleBridgeCore` | `AppleBridgeCore` | Models, errors, service protocols |
  | `AppleBridgeContacts` | `AppleBridgeContacts` | `ContactsAdapter` (CNContactStore), `AppleScriptContactsAdapter`, `ContactsFrameworkService` |
  | `AppleBridgeEventKit` | `AppleBridgeEventKit` | `EventKitAdapter`, calendar and reminders services |

  Contacts and EventKit consumers do not link sqlite3. Other adapters
  (Mail, Maps, Messages, Notes) remain internal to the executable.
- Round-trip system tests for the `CNContactStore` write path, now that it is
  public API rather than an unused alternative to the AppleScript adapter.

### Changed

- Modules are prefixed so they cannot collide with a consumer's own targets:
  `Core` is now `AppleBridgeCore`, and the single `Adapters` module is split
  into one module per surface. Code that built against a local branch using
  `import Core` / `import Adapters` needs the new names.

### Fixed

- `ContactsAdapter` (CNContactStore) stored standard labels as custom ones:
  `"work"` became a custom label spelled "work" rather than Contacts' Work
  label. Standard names (`home`, `work`, `mobile`, `iphone`, `homepage`, …) now
  map to the Contacts constants.
- `ContactsAdapter` returned labels translated into the system language
  (`"travail"` on a French Mac). It now returns the same locale-independent
  labels as the AppleScript adapter.

## [3.1.0] — 2026-09-23

### Added

- `contacts_create` and `contacts_update` tools (37 tools; Contacts 4 → 6).
  Create requires a given or family name — an organization alone is rejected.
  Update writes only the fields supplied: an absent field is left alone, an
  empty string or empty array clears it, and a supplied collection replaces the
  stored one (send the existing entries too to add one).
- Contacts carry `givenName`, `familyName`, `organization`, `jobTitle`, `note`,
  and labelled multi-value `emails`, `phones`, and `urls`. Multi-value fields
  accept either a string array or `[{label, value}]` objects. `email` and
  `phone` remain as projections of the first entry, so existing clients see the
  same wire shape.

- `LICENSE` (MIT). The README had stated the MIT license, but the file itself
  was missing from the repository and from release archives.

### Changed

- Contact creation commits the person and all its entries in one save, so a
  failure part-way leaves nothing behind.
- Contact labels are normalized (`home`, not `_$!<Home>!$_`).
- The Contacts privacy prompt now says the assistant may add or update
  contacts, not only read them.
- Building from source now requires Swift 6.2+ / Xcode 26.0+ (was stated as
  6.0+, which CI never tested). swift-collections 1.7 requires Swift tools
  6.2. Pre-built binaries still run on macOS 13+.
- Developer ID builds (release workflow and `install.sh`) embed
  `AppleBridge.entitlements`, which the hardened runtime consults for
  in-process Calendar, Reminders and Contacts access.
- Release notarization must return Apple's `Accepted` verdict; a rejected
  binary fails the release instead of shipping as notarized.
- Transitive dependencies updated: swift-nio 2.103.0, swift-collections 1.7.0,
  eventsource 1.5.1, swift-log 1.15.1, swift-system 1.8.1.

### Fixed

- Multi-paragraph contact notes no longer corrupt the record: the AppleScript
  transfer format uses ASCII control separators instead of tab and newline.
- Passing both `email` and `emails` (or `phone` and `phones`) is rejected as
  ambiguous rather than silently merged.
- Every user-supplied contact string is escaped before it reaches AppleScript.

### Known limitations

- The CNContactStore adapter (not the default) cannot read notes: that key
  requires Apple's restricted `com.apple.developer.contacts.notes`
  entitlement. The default AppleScript adapter is unaffected.

## [3.0.15] — 2026-08-05

### Fixed

- Calendar read access: `Info.plist` declares the full-access usage strings,
  and a write-only grant now reports a clear error instead of "not found".
- README tool table corrected to the 35 shipped tools; a test now keeps the
  README and the tool registry in agreement.
- Version single-sourced; `Info.plist` and the MCP handshake can no longer
  disagree.

### Added

- Documentation for granting permissions when launched by an MCP host, the
  AppleScript search scale limit, and Messages' Full Disk Access requirement.
- `docs/code-signing.md` and a signing step in `scripts/install.sh` that binds
  the embedded `Info.plist`.

### Changed

- swift-sdk 0.12.1, pinned by a committed `Package.resolved`.
