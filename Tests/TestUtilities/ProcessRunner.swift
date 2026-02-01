import Foundation

/// Shared process runner for executing the apple-bridge executable in tests.
///
/// This utility is used by both E2E tests and System tests to run the apple-bridge
/// executable and capture its output. It provides a consistent interface for:
/// - Finding the executable in various build locations
/// - Running with timeout protection
/// - Capturing stdout/stderr
///
/// ## Usage
/// ```swift
/// let (stdout, stderr) = try await ProcessRunner.runAppleBridge(input: """
///     {"jsonrpc":"2.0","id":1,"method":"initialize","params":{...}}
///     {"jsonrpc":"2.0","id":2,"method":"tools/call","params":{...}}
///     """)
/// ```
///
/// ## Environment Variables
/// The runner searches for the executable in this order:
/// 1. `BUILT_PRODUCTS_DIR` (Xcode builds)
/// 2. `BUILD_DIR` (Swift Package Manager)
/// 3. Common relative paths (`.build/debug/`, `.build/release/`)
/// 4. System PATH via `/usr/bin/which`
public enum ProcessRunner {

    // MARK: - Constants

    /// Default timeout for process execution in seconds.
    private static let defaultTimeout: TimeInterval = 5.0

    /// Poll interval when waiting for process completion.
    private static let pollInterval: Duration = .milliseconds(50)

    /// Standard initialize message for MCP protocol handshake.
    ///
    /// Use this constant to avoid duplicating the JSON-RPC initialize message
    /// across multiple tests.
    public static let initializeMessage = """
    {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
    """

    // MARK: - Public Methods

    /// Runs the apple-bridge executable with the given input and returns stdout/stderr.
    ///
    /// This method starts the apple-bridge process, sends the provided JSON-RPC messages
    /// via stdin, waits for the process to complete (with timeout), and captures all output.
    ///
    /// - Parameter input: The JSON-RPC messages to send to stdin (newline-delimited)
    /// - Returns: A tuple of (stdout, stderr) output strings
    /// - Throws: `ProcessRunnerError.executableNotFound` if the executable cannot be located,
    ///           `ProcessRunnerError.timeout` if the process doesn't complete within the timeout
    public static func runAppleBridge(input: String) async throws -> (stdout: String, stderr: String) {
        let executableURL = try findExecutable()

        let process = Process()
        process.executableURL = executableURL
        // Skip permission requests in test environment to avoid blocking on TCC prompts.
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["APPLE_BRIDGE_SKIP_PERMISSIONS": "1"]
        ) { _, new in new }

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

        while process.isRunning {
            if Date().timeIntervalSince(startTime) > defaultTimeout {
                process.terminate()
                throw ProcessRunnerError.timeout
            }
            try await Task.sleep(for: pollInterval)
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
    /// Searches for the executable in the following order:
    /// 1. `BUILT_PRODUCTS_DIR` environment variable (Xcode builds)
    /// 2. `BUILD_DIR` environment variable (Swift Package Manager)
    /// 3. Common relative paths from the current directory
    /// 4. System PATH via `/usr/bin/which`
    ///
    /// - Returns: The URL to the executable
    /// - Throws: `ProcessRunnerError.executableNotFound` if the executable cannot be located
    public static func findExecutable() throws -> URL {
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

        // Try `which` as fallback (errors are expected and ignored here)
        if let pathFromWhich = try? findExecutableViaWhich() {
            return pathFromWhich
        }

        throw ProcessRunnerError.executableNotFound
    }

    // MARK: - Private Methods

    /// Attempts to find the executable using the system `which` command.
    ///
    /// - Returns: The URL to the executable if found in PATH
    /// - Throws: If the executable is not found in PATH
    private static func findExecutableViaWhich() throws -> URL {
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["apple-bridge"]

        let pipe = Pipe()
        whichProcess.standardOutput = pipe

        try whichProcess.run()
        whichProcess.waitUntilExit()

        guard whichProcess.terminationStatus == 0 else {
            throw ProcessRunnerError.executableNotFound
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            throw ProcessRunnerError.executableNotFound
        }

        return URL(fileURLWithPath: path)
    }
}

/// Errors that can occur during process execution.
///
/// These errors indicate infrastructure problems with running tests,
/// not failures in the code being tested.
public enum ProcessRunnerError: Error, Sendable, CustomStringConvertible {
    /// The apple-bridge executable could not be found.
    ///
    /// This typically means the project hasn't been built yet.
    /// Run `swift build` to create the executable.
    case executableNotFound

    /// The process did not complete within the allowed time.
    ///
    /// This may indicate the server is hanging or there's a deadlock.
    case timeout

    public var description: String {
        switch self {
        case .executableNotFound:
            return "Could not find apple-bridge executable. Run 'swift build' first."
        case .timeout:
            return "Process timed out waiting for response"
        }
    }
}
