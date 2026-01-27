import Foundation
import Core

/// Executes an async operation with a timeout.
///
/// If the operation completes within the specified duration, its result is returned.
/// If the operation exceeds the timeout, a `ToolError.deadlineExceeded` is thrown and the
/// operation's task is cancelled.
///
/// ## Example
/// ```swift
/// let result = try await withTimeout(duration: .seconds(5)) {
///     await someSlowOperation()
/// }
/// ```
///
/// - Parameters:
///   - duration: The maximum time to wait for the operation to complete.
///   - operation: The async operation to execute.
/// - Returns: The result of the operation if it completes within the timeout.
/// - Throws: `ToolError.deadlineExceeded` if the operation exceeds the timeout, or any error
///           thrown by the operation itself.
public func withTimeout<T: Sendable>(
    duration: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Start the main operation
        group.addTask {
            try await operation()
        }

        // Start the timeout task
        group.addTask {
            try await Task.sleep(for: duration)
            throw ToolError.deadlineExceeded(seconds: Int(duration.seconds))
        }

        // Wait for the first task to complete
        guard let result = try await group.next() else {
            throw ToolError.deadlineExceeded(seconds: Int(duration.seconds))
        }

        // Cancel the remaining task
        group.cancelAll()

        return result
    }
}

// MARK: - Duration Extensions

extension Duration {
    /// The duration in seconds as a Double.
    var seconds: Double {
        let components = self.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
