import Testing
import Core
@testable import MCPServer
import TestUtilities

@Suite("AppleServices Tests")
struct AppleServicesTests {

    @Test("AppleServices is Sendable")
    func testAppleServicesIsSendable() async throws {
        // Compile-time check: if this compiles, AppleServices is Sendable
        let services = makeTestServices()

        // Verify we can pass it across actor boundaries
        let task = Task {
            // Using services in another task confirms Sendable
            let _ = services.calendar
            return true
        }

        let result = await task.value
        #expect(result == true)
    }

    @Test("AppleServicesProtocol provides all required services")
    func testAppleServicesProtocolProperties() async throws {
        let services = makeTestServices()

        // Verify all services are accessible
        let _ = services.calendar
        let _ = services.reminders
        let _ = services.contacts
        let _ = services.notes
        let _ = services.messages
        let _ = services.mail
        let _ = services.maps

        // If we get here without compiler errors, the protocol is correctly defined
        #expect(Bool(true))
    }

    @Test("Production AppleServices can be created")
    func testProductionAppleServicesCreation() async throws {
        // Create with mock services (simulating production use)
        let services = AppleServices(
            calendar: MockCalendarService(),
            reminders: MockRemindersService(),
            contacts: MockContactsService(),
            notes: MockNotesService(),
            messages: MockMessagesService(),
            mail: MockMailService(),
            maps: MockMapsService()
        )

        // Verify it conforms to protocol
        let protocolServices: any AppleServicesProtocol = services
        let _ = protocolServices.calendar

        #expect(Bool(true), "AppleServices created and accessible")
    }

    @Test("TestServices can be used as AppleServicesProtocol")
    func testTestServicesAsProtocol() async throws {
        let testServices = makeTestServices()

        // Can be assigned to protocol type
        let protocolServices: any AppleServicesProtocol = testServices

        // Can be passed to ToolRegistry
        let registry = ToolRegistry.create(services: protocolServices)

        let definitions = await registry.definitions
        #expect(definitions.count == 37)
    }
}
