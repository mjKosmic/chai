import Testing
@testable import Chai

// MARK: - Program.Send() Tests

@Suite("Program.Send")
struct ProgramSendTests {

    @Test func sendBeforeRunBuffersMessage() {
        // Verify that send() doesn't crash when called before run().
        struct DummyModel: Model {
            func initialize() -> Command? { nil }
            mutating func update(_ msg: any Message) -> Command? { nil }
            func view() -> ViewOutput { "test" }
        }

        let program = Program(DummyModel())
        // Should not crash — messages are buffered.
        struct PingMsg: Message {}
        program.send(PingMsg())
    }

    @Test func programHasSendMethod() {
        // Compile-time verification that send() exists and is callable
        // from outside the event loop (i.e., not async).
        struct DummyModel: Model {
            func initialize() -> Command? { nil }
            mutating func update(_ msg: any Message) -> Command? { nil }
            func view() -> ViewOutput { "" }
        }
        let program = Program(DummyModel())
        // This line verifies the API exists and compiles.
        let _: (any Message) -> Void = program.send
    }
}
