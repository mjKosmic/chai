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

            var body: ViewOutput { ponged ? "Ponged!" : "Waiting..." }
        }

        var m = PingPong()
        let cmd = m.update(PingMsg())
        #expect(cmd != nil)
        #expect(m.body.content == "Waiting...") // ponged not yet set

        // Simulate the runtime delivering the PongMsg.
        _ = m.update(PongMsg())
        #expect(m.body.content == "Ponged!")
    }

    // MARK: - .clearScreen

    @Test func clearScreenCase() {
        let cmd = Command.clearScreen
        if case .clearScreen = cmd {
            // pass
        } else {
            Issue.record("Expected .clearScreen")
        }
    }

    // MARK: - .requestWindowSize

    @Test func requestWindowSizeCase() {
        let cmd = Command.requestWindowSize
        if case .requestWindowSize = cmd {
            // pass
        } else {
            Issue.record("Expected .requestWindowSize")
        }
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

// MARK: - ClearScreen Command Tests

@Suite("ClearScreen Command")
struct ClearScreenCommandTests {

    @Test func clearScreenRendererIntegration() async {
        // ClearScreen should clear the terminal and reset the render cache.
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(ViewOutput("Existing content"))
        await renderer.flush()
        mock.reset()

        await renderer.clearScreen()
        #expect(mock.output.contains(ANSI.eraseEntireScreen))
        #expect(mock.output.contains(ANSI.cursorHome))

        // After clearScreen, the same content should be re-rendered
        // because the cache was cleared.
        await renderer.flush()
        #expect(mock.output.contains("Existing content"))
    }
}

// MARK: - Command Helpers

@Suite("New Command Cases")
struct NewCommandCaseTests {

    @Test func clearScreenPatternMatch() {
        let cmd = Command.clearScreen
        #expect(cmd.isClearScreen)
        #expect(!cmd.isQuit)
        #expect(!cmd.isPerform)
    }

    @Test func requestWindowSizePatternMatch() {
        let cmd = Command.requestWindowSize
        #expect(cmd.isRequestWindowSize)
        #expect(!cmd.isQuit)
        #expect(!cmd.isPerform)
    }

    @Test func modelCanReturnClearScreen() {
        struct ClearModel: Model {
            func initialize() -> Command? { nil }
            mutating func update(_ msg: any Message) -> Command? {
                if let key = msg as? KeyMsg, key.type == .ctrl("l") {
                    return .clearScreen
                }
                return nil
            }
            var body: ViewOutput { "Press Ctrl+L to clear" }
        }

        var model = ClearModel()
        let cmd = model.update(KeyMsg(type: .ctrl("l")))
        #expect(cmd?.isClearScreen == true)
    }

    @Test func modelCanReturnRequestWindowSize() {
        struct SizeModel: Model {
            func initialize() -> Command? { .requestWindowSize }
            mutating func update(_ msg: any Message) -> Command? { nil }
            var body: ViewOutput { "Waiting for size..." }
        }

        let model = SizeModel()
        let cmd = model.initialize()
        #expect(cmd?.isRequestWindowSize == true)
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
    var isClearScreen: Bool {
        if case .clearScreen = self { return true }
        return false
    }
    var isRequestWindowSize: Bool {
        if case .requestWindowSize = self { return true }
        return false
    }
}
