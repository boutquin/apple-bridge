import Testing
import Foundation
@testable import Core

/// Guards the version single-source-of-truth.
///
/// `AppleBridgeVersion.current` is reported to MCP clients in the `initialize`
/// handshake; `Info.plist`'s `CFBundleShortVersionString` / `CFBundleVersion` are
/// embedded into the binary via `-sectcreate __TEXT __info_plist`. Nothing in the
/// build compares them, so they silently diverged: the constant reached `3.0.15`
/// while the plist sat at its original `1.0.0` for the life of the project.
///
/// These tests make that drift a red build instead of a discovery.
@Suite("Version Tests")
struct VersionTests {

    /// Locates `Info.plist` at the package root, derived from this file's own path
    /// so the test does not depend on the process working directory (which differs
    /// between `swift test`, Xcode, and CI).
    private static var infoPlistURL: URL {
        URL(fileURLWithPath: #filePath)          // Tests/CoreTests/VersionTests.swift
            .deletingLastPathComponent()         // Tests/CoreTests
            .deletingLastPathComponent()         // Tests
            .deletingLastPathComponent()         // <package root>
            .appendingPathComponent("Info.plist")
    }

    private static func infoPlist() throws -> [String: Any] {
        let data = try Data(contentsOf: infoPlistURL)
        let parsed = try PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        )
        return try #require(parsed as? [String: Any])
    }

    @Test("Info.plist is present and parseable at the package root")
    func testInfoPlistReadable() throws {
        #expect(FileManager.default.fileExists(atPath: Self.infoPlistURL.path))
        let plist = try Self.infoPlist()
        #expect(!plist.isEmpty)
    }

    @Test("CFBundleShortVersionString matches AppleBridgeVersion.current")
    func testShortVersionMatchesConstant() throws {
        let plist = try Self.infoPlist()
        let short = try #require(plist["CFBundleShortVersionString"] as? String)
        #expect(
            short == AppleBridgeVersion.current,
            """
            Info.plist CFBundleShortVersionString (\(short)) != \
            AppleBridgeVersion.current (\(AppleBridgeVersion.current)). \
            Update Info.plist and Sources/Core/Version.swift together.
            """
        )
    }

    @Test("CFBundleVersion matches AppleBridgeVersion.current")
    func testBundleVersionMatchesConstant() throws {
        let plist = try Self.infoPlist()
        let build = try #require(plist["CFBundleVersion"] as? String)
        #expect(
            build == AppleBridgeVersion.current,
            """
            Info.plist CFBundleVersion (\(build)) != \
            AppleBridgeVersion.current (\(AppleBridgeVersion.current)). \
            Update Info.plist and Sources/Core/Version.swift together.
            """
        )
    }

    @Test("Version is well-formed MAJOR.MINOR.PATCH")
    func testVersionShape() throws {
        let parts = AppleBridgeVersion.current.split(separator: ".")
        #expect(parts.count == 3, "Expected three dot-separated components")
        for part in parts {
            #expect(!part.isEmpty)
            // Computed before the macro sees it: #expect cannot decompose a
            // keypath-based allSatisfy call (it reads the argument as throwing).
            let isNumeric = part.allSatisfy { $0.isNumber }
            #expect(isNumeric, "Component '\(part)' is not numeric")
        }
    }

    /// The privacy usage descriptions are load-bearing, not decorative: without
    /// `NSCalendarsFullAccessUsageDescription`, `requestFullAccessToEvents()` is
    /// auto-denied with no prompt and the server is permanently capped at
    /// write-only calendar access — the exact failure diagnosed in
    /// `specs/done/chore-calendar-event-identifier-roundtrip.md`.
    @Test("Required macOS 14+ privacy usage descriptions are present and non-empty")
    func testPrivacyUsageDescriptionsPresent() throws {
        let plist = try Self.infoPlist()
        let required = [
            "NSCalendarsFullAccessUsageDescription",
            "NSCalendarsWriteOnlyAccessUsageDescription",
            "NSRemindersFullAccessUsageDescription",
            "NSContactsUsageDescription",
            "NSAppleEventsUsageDescription",
        ]
        for key in required {
            let value = plist[key] as? String
            #expect(value != nil, "Missing required Info.plist key: \(key)")
            #expect(!(value ?? "").isEmpty, "Empty usage description for: \(key)")
        }
    }
}
