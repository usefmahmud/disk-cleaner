import Foundation

struct ShellResult: Sendable {
    var status: Int32
    var stdout: String
    var stderr: String

    var succeeded: Bool { status == 0 }
    var output: String {
        stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ShellError: LocalizedError {
    case executableNotFound(String)
    case launchFailed(String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let name):
            return "\(name) is not installed or isn't available on this Mac."
        case .launchFailed(let message):
            return message
        case .timedOut(let name):
            return "\(name) took too long to respond."
        }
    }
}

enum Shell {
    private static let searchPaths = [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin"
    ]

    static func findExecutable(_ name: String) -> String? {
        if name.hasPrefix("/") {
            return FileManager.default.isExecutableFile(atPath: name) ? name : nil
        }
        for directory in searchPaths {
            let candidate = directory + "/" + name
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    static func run(
        _ executable: String,
        arguments: [String] = [],
        requiresAdmin: Bool = false,
        timeout: TimeInterval = 90
    ) async throws -> ShellResult {
        guard let resolved = findExecutable(executable) else {
            throw ShellError.executableNotFound(executable)
        }

        if requiresAdmin {
            let command = ([resolved] + arguments)
                .map(shellQuoted)
                .joined(separator: " ")
            let script = "do shell script \"\(appleScriptQuoted(command))\" with administrator privileges"
            return try await launch(
                "/usr/bin/osascript",
                arguments: ["-e", script],
                displayName: executable,
                timeout: timeout
            )
        }

        return try await launch(
            resolved,
            arguments: arguments,
            displayName: executable,
            timeout: timeout
        )
    }

    static func runCapturing(
        _ executable: String,
        arguments: [String] = [],
        timeout: TimeInterval = 20
    ) async -> ShellResult? {
        guard let resolved = findExecutable(executable) else { return nil }
        return try? await launch(
            resolved,
            arguments: arguments,
            displayName: executable,
            timeout: timeout
        )
    }

    private static func launch(
        _ path: String,
        arguments: [String],
        displayName: String,
        timeout: TimeInterval
    ) async throws -> ShellResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outPipe = Pipe()
            let errPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            process.standardOutput = outPipe
            process.standardError = errPipe
            process.environment = processEnvironment()

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ShellError.launchFailed(error.localizedDescription))
                return
            }

            let state = ProcessState()
            let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                if state.claimTermination() {
                    process.terminate()
                    let pid = process.processIdentifier
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                        if process.isRunning {
                            kill(pid, SIGKILL)
                        }
                    }
                }
            }
            timer.resume()

            let outBox = DataBox()
            let errBox = DataBox()
            let group = DispatchGroup()

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                outBox.set(outPipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }

            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                errBox.set(errPipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }

            group.notify(queue: .global(qos: .userInitiated)) {
                process.waitUntilExit()
                timer.cancel()

                if state.wasTimedOut {
                    continuation.resume(throwing: ShellError.timedOut(displayName))
                    return
                }

                continuation.resume(returning: ShellResult(
                    status: process.terminationStatus,
                    stdout: String(data: outBox.value, encoding: .utf8) ?? "",
                    stderr: String(data: errBox.value, encoding: .utf8) ?? ""
                ))
            }
        }
    }

    private static func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let currentPath = environment["PATH"] ?? ""
        environment["PATH"] = searchPaths.joined(separator: ":") + ":" + currentPath
        return environment
    }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuoted(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private final class DataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func set(_ data: Data) {
        lock.lock()
        storage = data
        lock.unlock()
    }
}

private final class ProcessState: @unchecked Sendable {
    private let lock = NSLock()
    private var terminated = false
    private var timedOut = false

    var wasTimedOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func claimTermination() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !terminated else { return false }
        terminated = true
        timedOut = true
        return true
    }
}
