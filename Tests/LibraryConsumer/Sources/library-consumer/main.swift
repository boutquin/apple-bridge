import AppleBridgeContacts
import AppleBridgeCore
import AppleBridgeEventKit
import Adapters
import Core

// Touches one public type from each library so the linker keeps them. Nothing
// here requests access or reads personal data: CI only builds this, and a
// local run just prints the type names.
let contactsService = ContactsFrameworkService(adapter: ContactsAdapter())
let calendarAdapter = EventKitAdapter()
let sample = Contact(id: "sample", displayName: "Sample")

print(consumerCoreMarker, consumerAdaptersMarker)
print(type(of: contactsService), type(of: calendarAdapter), sample.displayName, AppleBridgeVersion.current)
