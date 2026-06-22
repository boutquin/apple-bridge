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
/// Thread-safe accumulator for pipe output collected via `readabilityHandler`.
private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var lastAppend = Date.distantPast

    func append(_ chunk: Data) {
        lock.lock(); defer { lock.unlock() }
        data.append(chunk)
        lastAppend = Date()
    }

    var snapshot: (data: Data, last: Date) {
        lock.lock(); defer { lock.unlock() }
        return (data, lastAppend)
    }
}

public enum ProcessRunner {

    // MARK: - Constants

    /// Default timeout for process execution in seconds.
    private static let defaultTimeout: TimeInterval = 5.0

    /// Poll interval when waiting for process completion.
    private static let pollInterval: Duration = .milliseconds(50)

    /// Standard initialize handshake for the MCP protocol: the `initialize`
    /// request followed by the `notifications/initialized` notification.
    ///
    /// swift-sdk 0.12 enforces the spec lifecycle — the server responds to
    /// `initialize` but ignores subsequent requests (`tools/list`, tool calls)
    /// until it receives `notifications/initialized`. Sending both here means
    /// every test that prefixes its requests with this constant completes the
    /// handshake before issuing real calls.
    public static let initializeMessage = """
    {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}
    {"jsonrpc":"2.0","method":"notifications/initialized"}
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

        // Accumulate output in the background. We can't use readDataToEndOfFile()
        // because we keep stdin open (see below), so the process never reaches EOF
        // on its own.
        let outBuf = OutputBuffer()
        let errBuf = OutputBuffer()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { outBuf.append(chunk) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { errBuf.append(chunk) }
        }

        try process.run()

        // Write input, adding newlines between messages, and KEEP STDIN OPEN.
        // Under MCP swift-sdk 0.12 the server handles each request in a detached
        // task and tears down its receive loop on stdin EOF — closing stdin here
        // would let the process exit before those responses flush to stdout. We
        // keep stdin open, wait for output to settle, then terminate.
        let inputWithNewlines = input
            .split(separator: "\n", omittingEmptySubsequences: true)
            .joined(separator: "\n") + "\n"

        if let inputData = inputWithNewlines.data(using: .utf8) {
            try stdinPipe.fileHandleForWriting.write(contentsOf: inputData)
        }

        // Wait until output settles (no new bytes for `quietPeriod` after some
        // output arrived), the process exits on its own, or the timeout elapses.
        let startTime = Date()
        let quietPeriod: TimeInterval = 0.4
        while Date().timeIntervalSince(startTime) < defaultTimeout {
            try await Task.sleep(for: pollInterval)
            if !process.isRunning { break }
            let (data, last) = outBuf.snapshot
            if !data.isEmpty, Date().timeIntervalSince(last) > quietPeriod { break }
        }

        // Signal EOF and stop the server, then give any final write a moment.
        try? stdinPipe.fileHandleForWriting.close()
        if process.isRunning { process.terminate() }
        try? await Task.sleep(for: .milliseconds(80))

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        let stdout = String(data: outBuf.snapshot.data, encoding: .utf8) ?? ""
        let stderr = String(data: errBuf.snapshot.data, encoding: .utf8) ?? ""

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
