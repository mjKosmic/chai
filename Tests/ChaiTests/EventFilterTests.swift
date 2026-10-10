import Testing
@testable import Chai

// MARK: - Event Filtering Tests

@Suite("Event Filtering")
struct EventFilteringTests {

    @Test func filterInitializerCompiles() {
        // Verify the filter initializer exists and type-checks.
        struct DummyModel: Model {
            func initialize() -> Command? { nil }
            mutating func update(_ msg: any Message) -> Command? { nil }
            var body: ViewOutput { "" }
        }

        // Filter that passes everything through.
        let _ = Program(DummyModel(), filter: { _, msg in msg })

        // Filter that suppresses quit.
        let _ = Program(DummyModel(), filter: { _, msg in
            if msg is QuitMsg { return nil }
            return msg
        })
    }

    @Test func filterCanTransformMessage() {
        // Simulate event filter behavior at the model level.
        struct Original: Message {}
        struct Transformed: Message {}

        struct TestModel: Model {
            var receivedTransformed = false
            func initialize() -> Command? { nil }
            mutating func update(_ msg: any Message) -> Command? {
                if msg is Transformed { receivedTransformed = true }
                return nil
            }
            var body: ViewOutput { "" }
        }

        let filter: @Sendable (TestModel, any Message) -> (any Message)? = { _, msg in
            if msg is Original { return Transformed() }
            return msg
        }

        var model = TestModel()
        let msg: any Message = Original()

        // Apply filter like the event loop would.
        if let transformed = filter(model, msg) {
            _ = model.update(transformed)
        }

        #expect(model.receivedTransformed)
    }

    @Test func filterCanSuppressMessage() {
        // Simulate event filter suppression.
        struct Suppressed: Message {}

        struct TestModel: Model {
            var updateCount = 0
            func initialize() -> Command? { nil }
            mutating func update(_ msg: any Message) -> Command? {
                updateCount += 1
                return nil
            }
            var body: ViewOutput { "" }
        }

        let filter: @Sendable (TestModel, any Message) -> (any Message)? = { _, msg in
            if msg is Suppressed { return nil }
            return msg
        }

        var model = TestModel()
        let messages: [any Message] = [
            KeyMsg(type: .enter),
            Suppressed(),
            KeyMsg(type: .space),
        ]

        for msg in messages {
            guard let filtered = filter(model, msg) else { continue }
            _ = model.update(filtered)
        }

        #expect(model.updateCount == 2)
    }

    @Test func filterWithOptionsInitializer() {
        struct DummyModel: Model {
            func initialize() -> Command? { nil }
            mutating func update(_ msg: any Message) -> Command? { nil }
            var body: ViewOutput { "" }
        }

        // Filter with explicit options array.
        let _ = Program(
            DummyModel(),
            options: [.withAltScreen],
            filter: { _, msg in msg }
        )
    }
}
