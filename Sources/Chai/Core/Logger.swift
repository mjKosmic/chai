import Foundation

// MARK: - ChaiLogger

/// A logging interface for Chai's internal diagnostics.
///
/// Since Chai owns stdout (the terminal), debug output must be directed
/// elsewhere. Implement this protocol for custom logging destinations,
/// or use the built-in ``FileLogger`` to write to a file on disk.
///
/// ```swift
/// let logger = try FileLogger(path: "/tmp/chai.log")
/// let program = Program(model, options: .withLogger(logger))
/// ```
///
/// Then in another terminal:
/// ```
/// tail -f /tmp/chai.log
/// ```
public protocol ChaiLogger: Sendable {
    /// Log a message at the given level.
    ///
    /// - Parameters:
    ///   - level: The severity of the log message.
    ///   - message: The message to log.
    func log(_ level: ChaiLogLevel, _ message: String) async
}

/// Severity levels for Chai diagnostic logging.
public enum ChaiLogLevel: String, Sendable, Comparable {
    case debug = "DEBUG"
    case info  = "INFO"
    case error = "ERROR"

    public static func < (lhs: ChaiLogLevel, rhs: ChaiLogLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    fileprivate var sortOrder: Int {
        switch self {
        case .debug: return 0
        case .info:  return 1
        case .error: return 2
        }
    }
}

// MARK: - FileLogger

/// A logger that appends messages to a file on disk.
///
/// Open the log file in another terminal with `tail -f <path>` to watch
/// events in real time while your Chai application is running.
///
/// ```swift
/// let logger = try FileLogger(path: "/tmp/chai.log")
/// let program = Program(model, options: .withLogger(logger))
/// ```
///
/// Each log line is formatted as:
/// ```
/// [2026-02-25T12:34:56Z] [chai] [DEBUG] Message text here
/// ```
public actor FileLogger: ChaiLogger {

    private let fileHandle: FileHandle
    private let prefix: String
    private let formatter = ISO8601DateFormatter()

    /// Create a file logger that writes to the given path.
    ///
    /// The file is created if it does not exist. New messages are appended
    /// to any existing content.
    ///
    /// - Parameters:
    ///   - path: The file path to write log messages to.
    ///   - prefix: A prefix included in each log line (default: `"chai"`).
    /// - Throws: ``ChaiLogError/cannotOpenFile(_:)`` if the file cannot be opened.
    public init(path: String, prefix: String = "chai") throws {
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        guard let handle = FileHandle(forWritingAtPath: path) else {
            throw ChaiLogError.cannotOpenFile(path)
        }
        handle.seekToEndOfFile()
        self.fileHandle = handle
        self.prefix = prefix
    }

    public func log(_ level: ChaiLogLevel, _ message: String) {
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] [\(prefix)] [\(level.rawValue)] \(message)\n"
        if let data = line.data(using: .utf8) {
            fileHandle.write(data)
        }
    }

    deinit {
        try? fileHandle.close()
    }
}

/// Errors that can occur when creating a ``FileLogger``.
public enum ChaiLogError: Error, CustomStringConvertible {
    /// The log file at the specified path could not be opened for writing.
    case cannotOpenFile(String)

    public var description: String {
        switch self {
        case .cannotOpenFile(let path):
            return "Cannot open log file for writing: \(path)"
        }
    }
}
