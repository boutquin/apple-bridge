import Foundation
import Testing

#if canImport(EventKit)
import EventKit
#endif

/// Helper utilities for system tests that interact with real macOS services.
///
/// System tests are opt-in because they:
/// - Require real system permissions (Calendar, Reminders, Full Disk Access)
/// - May have side effects on the user's data
/// - Cannot run in CI environments without proper entitlements
///
/// ## Enabling System Tests
///
/// Set the environment variable before running tests:
/// ```bash
/// APPLE_BRIDGE_SYSTEM_TESTS=1 swift test --filter SystemTests
/// ```
///
/// ## Manual QA Tests
///
/// Some tests require specific permission states that cannot be automated.
/// These are gated by `APPLE_BRIDGE_MANUAL_QA=1` in addition to the system tests flag.
enum SystemTestHelper {

    // MARK: - Environment Checks

    /// Returns true if system tests are enabled via environment variable.
    ///
    /// System tests interact with real macOS services and require:
    /// - EventKit permissions (Calendar, Reminders)
    /// - Full Disk Access (Notes, Messages)
    /// - Contacts access
    static var systemTestsEnabled: Bool {
        ProcessInfo.processInfo.environment["APPLE_BRIDGE_SYSTEM_TESTS"] == "1"
    }

    /// Returns true if the test runner holds **full** calendar access.
    ///
    /// Calendar round-trip tests need to read events back and to delete what
    /// they create. Under macOS 14+ write-only ("Add events only") access,
    /// writes succeed but reads — including the by-id lookup that `deleteEvent`
    /// needs to find and remove the event — return nothing, so a create-test
    /// run would leak an undeletable event. Gating on full access keeps those
    /// tests from running (and leaking) until the grant is upgraded.
    ///
    /// Note: for a Claude-launched process the grant is attributed to the
    /// responsible parent (Claude), so the System Settings entry to upgrade is
    /// under Claude, not apple-bridge.
    static var calendarFullAccess: Bool {
        #if canImport(EventKit)
        if #available(macOS 14.0, *) {
            return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        } else {
            return EKEventStore.authorizationStatus(for: .event) == .authorized
        }
        #else
        return false
        #endif
    }

    /// Returns true if manual QA environment is configured.
    ///
    /// Manual QA tests require specific system states that cannot be automated, such as:
    /// - Full Disk Access being DENIED
    /// - Specific permission configurations
    static var manualQAEnabled: Bool {
        ProcessInfo.processInfo.environment["APPLE_BRIDGE_MANUAL_QA"] == "1"
    }
}
