import Foundation

/// Shared test helper for E2E tests.
///
/// Provides utilities for running the apple-bridge executable and capturing output.
enum E2ETestHelper {

    /// Runs the apple-bridge executable with the given input and returns stdout/stderr.
    ///
    /// - Parameter input: The JSON-RPC messages to send to stdin (newline-delimited)
    /// - Returns: A tuple of (stdout, stderr) output strings
    /// - Throws: If the process fails to start or times out
    static func runAppleBridge(input: String) async throws -> (stdout: String, stderr: String) {
        let executableURL = try findExecutable()

        let process = Process()
        process.executableURL = executableURL

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Write input to stdin, adding newlines between messages
        let inputWithNewlines = input
            .split(separator: "\n", omittingEmptySubsequences: true)
            .joined(separator: "\n") + "\n"

        if let inputData = inputWithNewlines.data(using: .utf8) {
            try stdinPipe.fileHandleForWriting.write(contentsOf: inputData)
        }

        // Close stdin to signal EOF
        try stdinPipe.fileHandleForWriting.close()

        // Wait for output with timeout
        let startTime = Date()
        let timeout: TimeInterval = 5.0

        while process.isRunning {
            if Date().timeIntervalSince(startTime) > timeout {
                process.terminate()
                throw E2EError.timeout
            }
            try await Task.sleep(for: .milliseconds(50))
        }

        // Read all output
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return (stdout, stderr)
    }

    /// Finds the apple-bridge executable in the build directory.
    ///
    /// - Returns: The URL to the executable
    /// - Throws: `E2EError.executableNotFound` if the executable cannot be located
    static func findExecutable() throws -> URL {
        let possiblePaths = [
            ".build/debug/apple-bridge",
            ".build/release/apple-bridge",
            "../../../.build/debug/apple-bridge",
            "../../../.build/release/apple-bridge"
        ]

        // Try BUILT_PRODUCTS_DIR (Xcode)
        if let builtProductsDir = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
            let path = URL(fileURLWithPath: builtProductsDir).appendingPathComponent("apple-bridge")
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        // Try BUILD_DIR (Swift Package Manager)
        if let buildDir = ProcessInfo.processInfo.environment["BUILD_DIR"] {
            let path = URL(fileURLWithPath: buildDir).appendingPathComponent("apple-bridge")
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }

        // Try relative paths
        let currentDir = FileManager.default.currentDirectoryPath
        for relativePath in possiblePaths {
            let fullPath = URL(fileURLWithPath: currentDir).appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: fullPath.path) {
                return fullPath
            }
        }

        // Try `which` as fallback
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["apple-bridge"]

        let pipe = Pipe()
        whichProcess.standardOutput = pipe

        try? whichProcess.run()
        whichProcess.waitUntilExit()

        if whichProcess.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
        }

        throw E2EError.executableNotFound
    }
}

/// Errors that can occur during E2E testing.
enum E2EError: Error, CustomStringConvertible {
    case executableNotFound
    case timeout

    var description: String {
        switch self {
        case .executableNotFound:
            return "Could not find apple-bridge executable. Run 'swift build' first."
        case .timeout:
            return "Process timed out waiting for response"
        }
    }
}
