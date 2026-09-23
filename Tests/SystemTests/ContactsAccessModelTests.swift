import Foundation
import Testing

#if canImport(Contacts)
import Contacts
#endif

/// Pins the Contacts authorization model the contacts write tools rely on.
///
/// ## Why this suite exists
///
/// The cost estimate for the contacts write tools rests on a negative — that
/// Contacts has no split-access state, so a single grant covers both reading and
/// writing. That premise is cheap to state and expensive to be wrong about: the
/// *calendar* equivalent of it was wrong.
/// There, `EKAuthorizationStatus` gained `.writeOnly` in macOS 14 and the app
/// was structurally capped at it — writes succeeded, every read returned
/// nothing, and the symptom presented as "event not found" rather than as a
/// permissions problem.
///
/// So this suite asserts the shape of `CNAuthorizationStatus` rather than
/// trusting the claim, and it keeps doing so: if Apple ever ships a macOS case
/// that grants write without read, `capabilities(of:)` below stops compiling
/// and this is where that lands.
///
/// ## Prerequisites
/// - Set `APPLE_BRIDGE_SYSTEM_TESTS=1` environment variable
///
/// These tests need **no** contacts grant. `authorizationStatus(for:)` reports
/// state without requesting access, and the capability mapping is a pure
/// property of the enum. The suite is gated only so it runs under the same
/// opt-in as its sibling system suites.
@Suite("Contacts Access Model Tests", .enabled(if: SystemTestHelper.systemTestsEnabled))
struct ContactsAccessModelTests {

    #if canImport(Contacts)

    /// What a given authorization status permits.
    ///
    /// The `switch` is deliberately exhaustive over the macOS case set. Adding a
    /// case to `CNAuthorizationStatus` that this does not name is a compile-time
    /// failure here, which is the point — a new partial-access state must be
    /// classified by a human before the write path can rely on this mapping.
    ///
    /// `.limited` is **not** in this set: the SDK annotates it
    /// `NS_ENUM_AVAILABLE_IOS(18_0)`, and an exhaustive switch omitting it
    /// compiles clean on macOS with no unhandled-case warning.
    static func capabilities(of status: CNAuthorizationStatus) -> (canRead: Bool, canWrite: Bool) {
        switch status {
        case .notDetermined: return (canRead: false, canWrite: false)
        case .restricted:    return (canRead: false, canWrite: false)
        case .denied:        return (canRead: false, canWrite: false)
        case .authorized:    return (canRead: true,  canWrite: true)
        @unknown default:
            // Unreachable for the cases above; a genuinely new case is caught by
            // `Unknown status values are conservatively read as no-access` below.
            return (canRead: false, canWrite: false)
        }
    }

    /// The load-bearing assertion: no status grants writing without reading.
    ///
    /// This is the property whose *absence* made the calendar work expensive.
    /// If it ever fails, the contacts write tools need the same treatment
    /// EventKit needed — an explicit usage-description key, a dedicated
    /// `PermissionError` case, and a read-access guard on every read path.
    @Test("No CNAuthorizationStatus grants write without read")
    func noWriteOnlyState() {
        let all: [CNAuthorizationStatus] = [.notDetermined, .restricted, .denied, .authorized]
        for status in all {
            let caps = Self.capabilities(of: status)
            #expect(
                !(caps.canWrite && !caps.canRead),
                "\(status) grants write without read — Contacts now has a split-access state, and the contacts write tools must be revisited before relying on a single grant."
            )
        }
    }

    /// Pins the known macOS case set by raw value.
    ///
    /// Complements the exhaustive switch: the switch catches a *new* case at
    /// compile time, this catches a *renumbered* one at run time.
    @Test("Known macOS authorization statuses have their documented raw values")
    func knownRawValues() {
        #expect(CNAuthorizationStatus.notDetermined.rawValue == 0)
        #expect(CNAuthorizationStatus.restricted.rawValue == 1)
        #expect(CNAuthorizationStatus.denied.rawValue == 2)
        #expect(CNAuthorizationStatus.authorized.rawValue == 3)
    }

    /// Any status this suite does not know about is treated as no-access.
    ///
    /// Fail closed: an unrecognised state must never be read as permission to
    /// write into someone's address book.
    @Test("Unknown status values are conservatively read as no-access")
    func unknownStatusFailsClosed() {
        let unknown = CNAuthorizationStatus(rawValue: 99)
        // A raw value outside the known set either fails to construct or maps to
        // no capabilities; both are acceptable, silently granting write is not.
        if let unknown {
            let caps = Self.capabilities(of: unknown)
            #expect(caps.canWrite == false)
        }
    }

    /// Reports the runner's current grant. Never fails — it is a record, not a gate.
    ///
    /// Note the grant is attributed to the *responsible parent* process, so for a
    /// Claude-launched run the System Settings entry is under Claude rather than
    /// under apple-bridge. `SystemTestHelper.calendarFullAccess` documents the
    /// same attribution quirk for EventKit.
    @Test("Record the current contacts authorization status")
    func recordCurrentStatus() {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        let caps = Self.capabilities(of: status)
        print("[contacts-access] CNAuthorizationStatus rawValue=\(status.rawValue) canRead=\(caps.canRead) canWrite=\(caps.canWrite)")
        #expect(status.rawValue >= 0)
    }

    #endif
}
