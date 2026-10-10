import Testing
@testable import Chai

// MARK: - Internal Message Filtering Tests

@Suite("Internal Message Filtering")
struct InternalMessageFilteringTests {

    @Test func batchMsgIsInternalMessage() {
        let msg: any Message = BatchMsg(commands: [])
        #expect(msg is InternalMessage)
    }

    @Test func sequenceMsgIsInternalMessage() {
        let msg: any Message = SequenceMsg(commands: [])
        #expect(msg is InternalMessage)
    }

    @Test func repaintMsgIsInternalMessage() {
        let msg: any Message = RepaintMsg()
        #expect(msg is InternalMessage)
    }

    @Test func printLineMsgIsInternalMessage() {
        let msg: any Message = PrintLineMsg(body: "test")
        #expect(msg is InternalMessage)
    }

    @Test func keyMsgIsNotInternalMessage() {
        let msg: any Message = KeyMsg(type: .enter)
        #expect(!(msg is InternalMessage))
    }

    @Test func windowSizeMsgIsNotInternalMessage() {
        let msg: any Message = WindowSizeMsg(width: 80, height: 24)
        #expect(!(msg is InternalMessage))
    }

    @Test func quitMsgIsNotInternalMessage() {
        let msg: any Message = QuitMsg()
        #expect(!(msg is InternalMessage))
    }

    @Test func customUserMessageIsNotInternalMessage() {
        struct MyMsg: Message {}
        let msg: any Message = MyMsg()
        #expect(!(msg is InternalMessage))
    }

    @Test func internalMessageDoesNotReachModel() {
        // Verify the model doesn't process internal messages by simulating
        // what the event loop does.
        struct Counter: Model {
            var updateCount = 0
            func initialize() -> Command? { nil }
            mutating func update(_ msg: any Message) -> Command? {
                updateCount += 1
                return nil
            }
            var body: ViewOutput { "Count: \(updateCount)" }
        }

        var model = Counter()

        // Simulate event loop behavior: skip internal messages.
        let messages: [any Message] = [
            KeyMsg(type: .enter),           // should reach model
            RepaintMsg(),                    // should NOT reach model
            PrintLineMsg(body: "test"),      // should NOT reach model
            KeyMsg(type: .space),            // should reach model
            BatchMsg(commands: []),           // should NOT reach model
        ]

        for msg in messages {
            if msg is InternalMessage { continue }
            _ = model.update(msg)
        }

        #expect(model.updateCount == 2)
    }
}
