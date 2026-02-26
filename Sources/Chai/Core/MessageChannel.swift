// MARK: - MessageChannel

/// Thread-safe message channel shared between ``Program`` and ``ProgramRunner``.
///
/// Wraps an ``AsyncStream`` and its continuation so that messages can be
/// injected from outside the event loop (via ``Program/send(_:)``) while
/// the runner consumes them.
final class MessageChannel: @unchecked Sendable {
    let stream: AsyncStream<any Message>
    let continuation: AsyncStream<any Message>.Continuation

    init() {
        // AsyncStream calls the build closure synchronously, so `cont` is
        // guaranteed to be set before the initializer body continues.
        var cont: AsyncStream<any Message>.Continuation!
        self.stream = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    func yield(_ msg: any Message) {
        continuation.yield(msg)
    }

    func finish() {
        continuation.finish()
    }
}
