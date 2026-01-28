import Foundation
import Testing

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

    /// Returns true if manual QA environment is configured.
    ///
    /// Manual QA tests require specific system states that cannot be automated, such as:
    /// - Full Disk Access being DENIED
    /// - Specific permission configurations
    static var manualQAEnabled: Bool {
        ProcessInfo.processInfo.environment["APPLE_BRIDGE_MANUAL_QA"] == "1"
    }
}
