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

    /// The app holds only write-only ("Add events only") calendar access.
    /// Writes succeed but every read (get / list / search / update / delete)
    /// returns nothing, because macOS forbids reading with this grant. Full
    /// Access is required to read events back.
    case calendarFullAccessRequired

    /// Reminders access was denied by the user.
    case remindersDenied

    /// Contacts access was denied by the user.
    case contactsDenied

    /// Full Disk Access was denied (required for Notes/Messages databases).
    /// The optional context describes which feature requires FDA (e.g., "Notes", "Messages").
    case fullDiskAccessDenied(context: String? = nil)

    /// Automation (AppleScript) access was denied for a specific app.
    case automationDenied(app: String)

    /// A user-friendly message describing the error and how to fix it.
    public var userMessage: String {
        switch self {
        case .calendarDenied:
            return "Calendar access denied. Please grant access in System Settings > Privacy & Security > Calendar."
        case .calendarFullAccessRequired:
            return "Full Access to Calendars is required to read events — current access is write-only ('Add events only') or not granted. Grant Full Access in System Settings > Privacy & Security > Calendars. For a Claude-launched server the entry is listed under Claude, not apple-bridge."
        case .remindersDenied:
            return "Reminders access denied. Please grant access in System Settings > Privacy & Security > Reminders."
        case .contactsDenied:
            return "Contacts access denied. Please grant access in System Settings > Privacy & Security > Contacts."
        case .fullDiskAccessDenied(let context):
            if let context = context {
                return "Full Disk Access required to read \(context) database. Please grant access in System Settings > Privacy & Security > Full Disk Access."
            } else {
                return "Full Disk Access denied. Please grant access in System Settings > Privacy & Security > Full Disk Access."
            }
        case .automationDenied(let app):
            return "Automation access denied for \(app). Please grant access in System Settings > Privacy & Security > Automation."
        }
    }
}
