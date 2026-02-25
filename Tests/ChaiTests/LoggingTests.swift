import Testing
import Foundation
@testable import Chai

// MARK: - Logging Tests

@Suite("Logging")
struct LoggingTests {

    @Test func fileLoggerWritesToFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let logPath = tmpDir.appendingPathComponent("chai_test_\(UUID().uuidString).log").path

        let logger = try FileLogger(path: logPath)
        logger.log(.debug, "Hello from test")
        logger.log(.info, "Info message")
        logger.log(.error, "Error message")

        let content = try String(contentsOfFile: logPath, encoding: .utf8)
        #expect(content.contains("Hello from test"))
        #expect(content.contains("Info message"))
        #expect(content.contains("Error message"))
        #expect(content.contains("[DEBUG]"))
        #expect(content.contains("[INFO]"))
        #expect(content.contains("[ERROR]"))
        #expect(content.contains("[chai]"))

        // Clean up.
        try? FileManager.default.removeItem(atPath: logPath)
    }

    @Test func fileLoggerCustomPrefix() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let logPath = tmpDir.appendingPathComponent("chai_test_\(UUID().uuidString).log").path

        let logger = try FileLogger(path: logPath, prefix: "myapp")
        logger.log(.debug, "Custom prefix")

        let content = try String(contentsOfFile: logPath, encoding: .utf8)
        #expect(content.contains("[myapp]"))
        #expect(!content.contains("[chai]"))

        try? FileManager.default.removeItem(atPath: logPath)
    }

    @Test func fileLoggerAppendsToExistingFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let logPath = tmpDir.appendingPathComponent("chai_test_\(UUID().uuidString).log").path

        // Write initial content.
        try "existing content\n".write(toFile: logPath, atomically: true, encoding: .utf8)

        let logger = try FileLogger(path: logPath)
        logger.log(.info, "New message")

        let content = try String(contentsOfFile: logPath, encoding: .utf8)
        #expect(content.contains("existing content"))
        #expect(content.contains("New message"))

        try? FileManager.default.removeItem(atPath: logPath)
    }

    @Test func fileLoggerIncludesTimestamp() throws {
        let tmpDir = FileManager.default.temporaryDirectory
        let logPath = tmpDir.appendingPathComponent("chai_test_\(UUID().uuidString).log").path

        let logger = try FileLogger(path: logPath)
        logger.log(.debug, "Timestamp check")

        let content = try String(contentsOfFile: logPath, encoding: .utf8)
        // ISO 8601 timestamps contain "T" and "Z" (or timezone offset).
        #expect(content.contains("202"))  // Year prefix
        #expect(content.contains("T"))    // ISO 8601 separator

        try? FileManager.default.removeItem(atPath: logPath)
    }

    @Test func chaiLogLevelComparable() {
        #expect(ChaiLogLevel.debug < ChaiLogLevel.info)
        #expect(ChaiLogLevel.info < ChaiLogLevel.error)
        #expect(ChaiLogLevel.debug < ChaiLogLevel.error)
        #expect(!(ChaiLogLevel.error < ChaiLogLevel.debug))
    }

    @Test func chaiLogErrorDescription() {
        let error = ChaiLogError.cannotOpenFile("/nonexistent/path")
        #expect(error.description.contains("/nonexistent/path"))
    }

    @Test func withLoggerProgramOption() {
        // Verify the .withLogger option compiles and can be pattern-matched.
        struct DummyLogger: ChaiLogger {
            func log(_ level: ChaiLogLevel, _ message: String) {}
        }

        let option = ProgramOption.withLogger(DummyLogger())
        if case .withLogger = option {
            // pass
        } else {
            Issue.record("Expected .withLogger")
        }
    }
}
