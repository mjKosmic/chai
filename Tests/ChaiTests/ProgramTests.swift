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
            var body: ViewOutput { "test" }
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
            var body: ViewOutput { "" }
        }
        let program = Program(DummyModel())
        // This line verifies the API exists and compiles.
        let _: (any Message) -> Void = program.send
    }

    @Test func programAcceptsDeclarativeSomeViewBody() {
        // Compile-time verification of the declarative wiring: a model
        // whose body is a structural view tree (not ViewOutput) is
        // accepted by Program. The event loop feeds `model.body` to
        // `Renderer.write(_:)`, whose generic View overload resolves
        // the tree — this model exercises literal expressions, custom
        // views, and control flow through that seam.
        struct DeclarativeModel: Model {
            var count = 0

            func initialize() -> Command? { nil }

            mutating func update(_ msg: any Message) -> Command? {
                if let key = msg as? KeyMsg {
                    switch key.type {
                    case .up: count += 1
                    case .down: count -= 1
                    default: break
                    }
                }
                return nil
            }

            @ViewBuilder var body: some View {
                Text("Counter")
                "Count: \(count)"
                if count > 0 {
                    Text("incremented")
                } else {
                    Text("start")
                }
                for letter in ["a", "b"] {
                    Text(letter)
                }
            }
        }

        let program = Program(DeclarativeModel())
        struct PingMsg: Message {}
        program.send(PingMsg())
    }
}
