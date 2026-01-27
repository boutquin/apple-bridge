import Testing
import Foundation
@testable import Core

@Suite("Contact Tests")
struct ContactTests {
    @Test func testContactRoundTrip() throws {
        let contact = Contact(
            id: "C1",
            displayName: "John Doe",
            email: "john@example.com",
            phone: "+1234567890"
        )
        let json = try JSONEncoder().encode(contact)
        let decoded = try JSONDecoder().decode(Contact.self, from: json)
        #expect(decoded.id == "C1")
        #expect(decoded.displayName == "John Doe")
        #expect(decoded.email == "john@example.com")
        #expect(decoded.phone == "+1234567890")
    }

    @Test func testContactWithNilOptionals() throws {
        let contact = Contact(
            id: "C2",
            displayName: "Jane Smith",
            email: nil,
            phone: nil
        )
        let json = try JSONEncoder().encode(contact)
        let decoded = try JSONDecoder().decode(Contact.self, from: json)
        #expect(decoded.email == nil)
        #expect(decoded.phone == nil)
    }

    @Test func testContactEquality() {
        let contact1 = Contact(id: "C1", displayName: "John", email: nil, phone: nil)
        let contact2 = Contact(id: "C1", displayName: "John", email: nil, phone: nil)
        #expect(contact1 == contact2)
    }
}
