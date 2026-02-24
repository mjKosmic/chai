import Testing
@testable import Chai

@Suite("Command")
struct CommandTests {

    // MARK: - .perform

    @Test func performDeliversMessage() async {
        struct Pong: Message {}
        var received: (any Message)?

        let cmd = Command.perform { Pong() }
        if case .perform(let work) = cmd {
            received = await work()
        }

        #expect(received is Pong)
    }

    // MARK: - .batch

    @Test func batchContainsAllCommands() {
        struct MsgA: Message {}
        struct MsgB: Message {}

        let a = Command.perform { MsgA() }
        let b = Command.perform { MsgB() }
        let batch = Command.batch([a, b])

        if case .batch(let cmds) = batch {
            #expect(cmds.count == 2)
        } else {
            Issue.record("Expected .batch")
        }
    }

    // MARK: - .sequence

    @Test func sequenceContainsAllCommands() {
        struct Step1: Message {}
        struct Step2: Message {}

        let s1 = Command.perform { Step1() }
        let s2 = Command.perform { Step2() }
        let seq = Command.sequence([s1, s2])

        if case .sequence(let cmds) = seq {
            #expect(cmds.count == 2)
        } else {
            Issue.record("Expected .sequence")
        }
    }

    // MARK: - .quit

    @Test func quitCaseIsQuit() {
        let cmd = Command.quit
        if case .quit = cmd {
            // pass
        } else {
            Issue.record("Expected .quit")
        }
    }

    // MARK: - .setWindowTitle

    @Test func setWindowTitleStoresTitle() {
        let cmd = Command.setWindowTitle("My App")
        if case .setWindowTitle(let t) = cmd {
            #expect(t == "My App")
        } else {
            Issue.record("Expected .setWindowTitle")
        }
    }

    // MARK: - .tick

    @Test func tickDeliversMessageAfterDelay() async {
        struct Ticked: Message {
            let instant: ContinuousClock.Instant
        }

        let before = ContinuousClock().now
        let cmd = Command.tick(.milliseconds(50)) { instant in Ticked(instant: instant) }

        if case .perform(let work) = cmd {
            let msg = await work()
            let after = ContinuousClock().now
            #expect(msg is Ticked)
            // Should have waited at least ~50ms.
            #expect(after >= before.advanced(by: .milliseconds(40)))
        } else {
            Issue.record("Expected .perform from .tick")
        }
    }

    // MARK: - .println

    @Test func printlnProducesPrintLineMsg() async {
        let cmd = Command.println("Hello, log!")
        if case .perform(let work) = cmd {
            let msg = await work()
            if let pl = msg as? PrintLineMsg {
                #expect(pl.body == "Hello, log!")
            } else {
                Issue.record("Expected PrintLineMsg")
            }
        } else {
            Issue.record("Expected .perform from .println")
        }
    }

    // MARK: - Model integration

    @Test func modelUpdateReturnsCommand() {
        struct PingMsg: Message {}
        struct PongMsg: Message {}

        struct PingPong: Model {
            var ponged = false

            func initialize() -> Command? { nil }

            mutating func update(_ msg: any Message) -> Command? {
                if msg is PingMsg {
                    return .perform { PongMsg() }
                }
                if msg is PongMsg {
                    ponged = true
                }
                return nil
            }

            func view() -> String { ponged ? "Ponged!" : "Waiting..." }
        }

        var m = PingPong()
        let cmd = m.update(PingMsg())
        #expect(cmd != nil)
        #expect(m.view() == "Waiting...") // ponged not yet set

        // Simulate the runtime delivering the PongMsg.
        _ = m.update(PongMsg())
        #expect(m.view() == "Ponged!")
    }

    // MARK: - QuitMsg

    @Test func quitMsgIsMessage() {
        let msg: any Message = QuitMsg()
        #expect(msg is QuitMsg)
    }

    // MARK: - WindowSizeMsg

    @Test func windowSizeMsgStoresDimensions() {
        let msg = WindowSizeMsg(width: 120, height: 40)
        #expect(msg.width == 120)
        #expect(msg.height == 40)
    }
}

// MARK: - Command Equatable helper (for test assertions only)

extension Command {
    var isQuit: Bool {
        if case .quit = self { return true }
        return false
    }
    var isPerform: Bool {
        if case .perform = self { return true }
        return false
    }
}
