import Foundation

/// Error type for permission/access denials.
public enum PermissionError: Error, Sendable {
    case calendarDenied
    case remindersDenied
    case contactsDenied
    case fullDiskAccessDenied
    case automationDenied(app: String)

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
