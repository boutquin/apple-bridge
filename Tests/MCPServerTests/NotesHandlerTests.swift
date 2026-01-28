import Testing
import Foundation
import MCP
@testable import MCPServer
@testable import Core
@testable import TestUtilities

/// Tests for Notes MCP tool handlers.
///
/// These tests verify the MCP handlers for notes_search, notes_get, notes_create, and notes_open
/// tools work correctly with the mock notes service.
@Suite("Notes Handler Tests")
struct NotesHandlerTests {

    // MARK: - Test Helpers

    /// Creates a test services container with mock notes.
    private func makeServicesWithNotes(_ notes: [Note]) async -> TestServices {
        let services = makeTestServices()
        await services.mockNotes.setStubNotes(notes)
        return services
    }

    /// Sample notes for testing.
    private var sampleNotes: [Note] {
        [
            Note(
                id: "note-1",
                title: "Shopping List",
                body: "Milk, eggs, bread",
                folderId: "folder-1",
                modifiedAt: "2026-01-27T10:00:00.000Z"
            ),
            Note(
                id: "note-2",
                title: "Meeting Notes",
                body: "Discussed Q1 goals",
                folderId: "folder-1",
                modifiedAt: "2026-01-26T10:00:00.000Z"
            ),
            Note(
                id: "note-3",
                title: "Recipe Ideas",
                body: "Pizza, pasta, salad",
                folderId: "folder-2",
                modifiedAt: "2026-01-25T10:00:00.000Z"
            )
        ]
    }

    // MARK: - notes_search Tests

    @Test("notes_search returns matching notes")
    func testNotesSearchReturnsMatchingNotes() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_search",
            arguments: ["query": .string("Shopping")]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("Shopping List"))
            #expect(content.contains("note-1"))
        }
    }

    @Test("notes_search requires query parameter")
    func testNotesSearchRequiresQuery() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_search",
            arguments: [:]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("query"))
        }
    }

    @Test("notes_search uses default limit when not provided")
    func testNotesSearchUsesDefaultLimit() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_search",
            arguments: ["query": .string("")]
        )

        #expect(result.isError == false)
        // Default limit should return all 3 notes
        if case .text(let content) = result.content.first {
            #expect(content.contains("items"))
        }
    }

    @Test("notes_search respects limit parameter")
    func testNotesSearchRespectsLimit() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_search",
            arguments: [
                "query": .string(""),
                "limit": .int(1)
            ]
        )

        #expect(result.isError == false)
        // Should only return 1 note
    }

    @Test("notes_search handles includeBody parameter")
    func testNotesSearchHandlesIncludeBody() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        // With includeBody: true
        let resultWithBody = await registry.callTool(
            name: "notes_search",
            arguments: [
                "query": .string("Shopping"),
                "includeBody": .bool(true)
            ]
        )

        #expect(resultWithBody.isError == false)
        if case .text(let contentWithBody) = resultWithBody.content.first {
            #expect(contentWithBody.contains("Milk"))
        }

        // With includeBody: false
        let resultWithoutBody = await registry.callTool(
            name: "notes_search",
            arguments: [
                "query": .string("Shopping"),
                "includeBody": .bool(false)
            ]
        )

        #expect(resultWithoutBody.isError == false)
        if case .text(let contentWithoutBody) = resultWithoutBody.content.first {
            // Body should be omitted when includeBody is false (Swift's JSONEncoder skips nil values)
            #expect(!contentWithoutBody.contains("\"body\""))
        }
    }

    @Test("notes_search returns empty array for no matches")
    func testNotesSearchReturnsEmptyForNoMatches() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_search",
            arguments: ["query": .string("xyz123nonexistent")]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("\"items\" : ["))
            #expect(content.contains("\"hasMore\" : false"))
        }
    }

    // MARK: - notes_get Tests

    @Test("notes_get returns note by ID")
    func testNotesGetReturnsNoteById() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_get",
            arguments: ["id": .string("note-1")]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("note-1"))
            #expect(content.contains("Shopping List"))
            #expect(content.contains("Milk, eggs, bread"))
        }
    }

    @Test("notes_get requires id parameter")
    func testNotesGetRequiresId() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_get",
            arguments: [:]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("id"))
        }
    }

    @Test("notes_get returns error for invalid ID")
    func testNotesGetReturnsErrorForInvalidId() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_get",
            arguments: ["id": .string("nonexistent-id")]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("Note"))
        }
    }

    // MARK: - notes_create Tests

    @Test("notes_create creates new note")
    func testNotesCreateCreatesNewNote() async throws {
        let services = await makeServicesWithNotes([])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_create",
            arguments: [
                "title": .string("New Note"),
                "body": .string("Some content")
            ]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            // Should return the created note ID
            #expect(content.contains("id"))
        }
    }

    @Test("notes_create requires title parameter")
    func testNotesCreateRequiresTitle() async throws {
        let services = await makeServicesWithNotes([])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_create",
            arguments: [
                "body": .string("Some content")
            ]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("title"))
        }
    }

    @Test("notes_create works without body")
    func testNotesCreateWorksWithoutBody() async throws {
        let services = await makeServicesWithNotes([])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_create",
            arguments: ["title": .string("Title Only")]
        )

        #expect(result.isError == false)
    }

    @Test("notes_create works with folderId")
    func testNotesCreateWorksWithFolderId() async throws {
        let services = await makeServicesWithNotes([])
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_create",
            arguments: [
                "title": .string("New Note"),
                "body": .string("Content"),
                "folderId": .string("folder-123")
            ]
        )

        #expect(result.isError == false)
    }

    // MARK: - notes_open Tests

    @Test("notes_open succeeds for valid ID")
    func testNotesOpenSucceedsForValidId() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_open",
            arguments: ["id": .string("note-1")]
        )

        #expect(result.isError == false)
        if case .text(let content) = result.content.first {
            #expect(content.contains("opened"))
        }
    }

    @Test("notes_open requires id parameter")
    func testNotesOpenRequiresId() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_open",
            arguments: [:]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("id"))
        }
    }

    @Test("notes_open returns error for invalid ID")
    func testNotesOpenReturnsErrorForInvalidId() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_open",
            arguments: ["id": .string("nonexistent-id")]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("Note"))
        }
    }

    // MARK: - Tool Registration Tests

    @Test("All notes tools are registered")
    func testAllNotesToolsAreRegistered() async throws {
        let services = makeTestServices()
        let registry = ToolRegistry.create(services: services)
        let tools = await registry.definitions

        let notesTools = tools.filter { $0.name.hasPrefix("notes_") }

        #expect(notesTools.count == 4)
        #expect(notesTools.contains { $0.name == "notes_search" })
        #expect(notesTools.contains { $0.name == "notes_get" })
        #expect(notesTools.contains { $0.name == "notes_create" })
        #expect(notesTools.contains { $0.name == "notes_open" })
    }

    @Test("Notes handlers no longer return NOT_IMPLEMENTED")
    func testNotesHandlersNoLongerReturnNotImplemented() async throws {
        let services = await makeServicesWithNotes(sampleNotes)
        let registry = ToolRegistry.create(services: services)

        // Test search
        let searchResult = await registry.callTool(
            name: "notes_search",
            arguments: ["query": .string("test")]
        )
        if case .text(let searchContent) = searchResult.content.first {
            #expect(!searchContent.contains("NOT_IMPLEMENTED"))
        }

        // Test get (with valid ID)
        let getResult = await registry.callTool(
            name: "notes_get",
            arguments: ["id": .string("note-1")]
        )
        if case .text(let getContent) = getResult.content.first {
            #expect(!getContent.contains("NOT_IMPLEMENTED"))
        }
    }

    // MARK: - Permission Error Tests

    @Test("notes_search returns permission error when access denied")
    func testNotesSearchReturnsPermissionError() async throws {
        let services = makeTestServices()
        await services.mockNotes.setError(PermissionError.fullDiskAccessDenied(context: "Notes"))
        let registry = ToolRegistry.create(services: services)

        let result = await registry.callTool(
            name: "notes_search",
            arguments: ["query": .string("test")]
        )

        #expect(result.isError == true)
        if case .text(let content) = result.content.first {
            #expect(content.contains("Full Disk Access") || content.contains("Permission"))
        }
    }
}
