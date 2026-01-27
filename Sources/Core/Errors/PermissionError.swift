import Foundation

/// Errors indicating macOS permission or access denials.
///
/// These errors occur when the application lacks the necessary system permissions
/// to access protected resources. Each case provides a user-friendly message with
/// instructions for granting access.
///
/// ## Handling Permission Errors
/// When a `PermissionError` is thrown, display the `userMessage` to guide the user
/// to the appropriate System Settings panel to grant access.
///
/// ## Example
/// ```swift
/// do {
///     let events = try await calendarAdapter.listEvents()
/// } catch let error as PermissionError {
///     print(error.userMessage)
///     // "Calendar access denied. Please grant access in System Settings..."
/// }
/// ```
public enum PermissionError: Error, Sendable {
    /// Calendar access was denied by the user.
    case calendarDenied

    /// Reminders access was denied by the user.
    case remindersDenied

    /// Contacts access was denied by the user.
    case contactsDenied

    /// Full Disk Access was denied (required for Messages/Mail databases).
    case fullDiskAccessDenied

    /// Automation (AppleScript) access was denied for a specific app.
    case automationDenied(app: String)

    /// A user-friendly message describing the error and how to fix it.
    public var userMessage: String {
        switch self {
        case .calendarDenied:
            return "Calendar access denied. Please grant access in System Settings > Privacy & Security > Calendar."
        case .remindersDenied:
            return "Reminders access denied. Please grant access in System Settings > Privacy & Security > Reminders."
        case .contactsDenied:
            return "Contacts access denied. Please grant access in System Settings > Privacy & Security > Contacts."
        case .fullDiskAccessDenied:
            return "Full Disk Access denied. Please grant access in System Settings > Privacy & Security > Full Disk Access."
        case .automationDenied(let app):
            return "Automation access denied for \(app). Please grant access in System Settings > Privacy & Security > Automation."
        }
    }
}
