import Testing
import Foundation
import MCP
@testable import MCPServer
import TestUtilities

/// Guards the README's advertised tool surface against the real registry.
///
/// The README's Features table is the first thing a prospective user reads, and
/// nothing verified it. By 2026-08-05 it had drifted badly: 12 shipped tools were
/// undocumented (`calendar_get`, `calendar_search`, `contacts_get`, `contacts_open`,
/// `mail_compose`, `messages_list_chats`, `messages_schedule`, `notes_get`,
/// `notes_open`, `reminders_get_lists`, `reminders_open`, `reminders_search`) and
/// one — `notes_list` — was advertised but had never existed in any form.
///
/// Documentation drift is invisible to a normal test suite because docs aren't
/// compiled. These tests make the README a checked artifact.
@Suite("README Tool Table Tests")
struct ReadmeToolTableTests {

    /// The README at the package root, located from this file's own path so the
    /// test does not depend on the process working directory.
    private static var readmeURL: URL {
        URL(fileURLWithPath: #filePath)          // Tests/MCPServerTests/ReadmeToolTableTests.swift
            .deletingLastPathComponent()         // Tests/MCPServerTests
            .deletingLastPathComponent()         // Tests
            .deletingLastPathComponent()         // <package root>
            .appendingPathComponent("README.md")
    }

    /// Every `domain_tool` token mentioned anywhere in the README, restricted to
    /// the seven real domain prefixes so prose like `swift_build` can't pollute it.
    private static func documentedToolNames() throws -> Set<String> {
        let text = try String(contentsOf: readmeURL, encoding: .utf8)
        let domains = ["calendar", "contacts", "mail", "maps", "messages", "notes", "reminders"]
        let pattern = "\\b(" + domains.joined(separator: "|") + ")_[a-z_]+"
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var found = Set<String>()
        for match in regex.matches(in: text, range: range) {
            if let r = Range(match.range, in: text) {
                found.insert(String(text[r]))
            }
        }
        return found
    }

    private static func registeredToolNames() async -> Set<String> {
        let registry = ToolRegistry.create(services: makeTestServices())
        return Set(await registry.definitions.map(\.name))
    }

    @Test("README documents every registered tool")
    func testNoUndocumentedTools() async throws {
        let registered = await Self.registeredToolNames()
        let documented = try Self.documentedToolNames()
        let missing = registered.subtracting(documented).sorted()
        #expect(
            missing.isEmpty,
            "Tools registered but absent from README.md: \(missing.joined(separator: ", "))"
        )
    }

    @Test("README advertises no tool that does not exist")
    func testNoPhantomTools() async throws {
        let registered = await Self.registeredToolNames()
        let documented = try Self.documentedToolNames()
        let phantom = documented.subtracting(registered).sorted()
        #expect(
            phantom.isEmpty,
            "Tools named in README.md but not registered: \(phantom.joined(separator: ", "))"
        )
    }

    @Test("README's stated tool count matches the registry")
    func testStatedCountMatches() async throws {
        let registered = await Self.registeredToolNames()
        let text = try String(contentsOf: Self.readmeURL, encoding: .utf8)
        #expect(
            text.contains("\(registered.count) MCP tools"),
            "README should state '\(registered.count) MCP tools' to match the registry"
        )
    }
}
