#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

import Foundation

/// Reads raw bytes from a file descriptor and emits parsed ``Message`` values
/// via an `AsyncStream`.
///
/// The reader runs a blocking `read(2)` call on a background thread so it
/// never blocks the Swift concurrency thread pool. Parsed messages are
/// delivered through the stream's continuation.
///
/// The reader thread is the sole owner of descriptor closing and stream
/// completion; `stop()` only signals cancellation. Lifecycle state is guarded
/// by a lock, which is what makes the unchecked `Sendable` conformance sound:
/// the descriptors and continuation are immutable `let`s, and all mutable
/// state is read and written under the lock.
///
/// Usage:
/// ```swift
/// let reader = InputReader(fileDescriptor: STDIN_FILENO)
/// for await message in reader.messages {
///     // handle message
/// }
/// ```
final class InputReader: @unchecked Sendable {

    // MARK: - Types

    /// Where the reader is in its lifecycle.
    enum LifecycleState: Sendable {
        /// The reader thread has not been started.
        case idle
        /// The reader thread is running or about to run.
        case running
        /// The loop has exited and the stream and descriptors are released.
        case finished
    }

    /// The stream of parsed input messages.
    let messages: AsyncStream<any Message>

    // MARK: - Private state

    private let continuation: AsyncStream<any Message>.Continuation
    private let fileDescriptor: Int32

    /// A pipe used to unblock the blocking `read()` call on shutdown.
    private let cancelReadFD: Int32
    private let cancelWriteFD: Int32

    /// Guards `state` and `cancelSignalled`. Never held across blocking I/O:
    /// the only work done while held is a single non-blocking pipe write.
    private let lock = NSLock()
    private var state: LifecycleState = .idle
    private var cancelSignalled = false

    // MARK: - Init

    init(fileDescriptor: Int32 = STDIN_FILENO) {
        self.fileDescriptor = fileDescriptor

        // Create a pipe for cancellation signalling.
        var pipeFDs: [Int32] = [0, 0]
        pipe(&pipeFDs)
        cancelReadFD  = pipeFDs[0]
        cancelWriteFD = pipeFDs[1]

        var localContinuation: AsyncStream<any Message>.Continuation!
        messages = AsyncStream { continuation in
            localContinuation = continuation
        }
        self.continuation = localContinuation
    }

    // MARK: - Lifecycle

    /// The current lifecycle state.
    var lifecycleState: LifecycleState {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    /// Start reading input on a background thread.
    ///
    /// Calling this more than once has no effect after the first call.
    func start() {
        lock.lock()
        guard state == .idle else {
            lock.unlock()
            return
        }
        state = .running
        lock.unlock()

        let thread = Thread { [weak self] in
            self?.readLoop()
        }
        thread.name = "chai.input-reader"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    /// Request that the reader stop and release its resources.
    ///
    /// The reader thread owns descriptor closing and stream completion, so
    /// this only signals cancellation. If the reader was never started, the
    /// resources are released here. Repeated calls are safe.
    func stop() {
        lock.lock()
        switch state {
        case .finished:
            lock.unlock()
        case .idle:
            state = .finished
            lock.unlock()
            releaseResources()
        case .running:
            // Signal while holding the lock: the reader transitions to
            // `.finished` and closes the descriptors under the same lock, so a
            // write cannot land on a recycled descriptor.
            if !cancelSignalled {
                cancelSignalled = true
                var byte: UInt8 = 1
                _ = Foundation.write(cancelWriteFD, &byte, 1)
            }
            lock.unlock()
        }
    }

    /// Close the cancellation descriptors and finish the stream exactly once.
    private func releaseResources() {
        Foundation.close(cancelReadFD)
        Foundation.close(cancelWriteFD)
        continuation.finish()
    }

    // MARK: - Read loop (runs on background thread)

    private func readLoop() {
        let bufSize = 256
        var buf = [UInt8](repeating: 0, count: bufSize)
        var leftover: [UInt8] = []

        while true {
            // Use select() to wait for either stdin data or the cancel signal.
            var readSet = fd_set()
            fdZero(&readSet)
            fdSet(fileDescriptor, set: &readSet)
            fdSet(cancelReadFD, set: &readSet)

            let maxFD = max(fileDescriptor, cancelReadFD) + 1
            let result = select(maxFD, &readSet, nil, nil, nil)

            if result <= 0 { break } // error or interrupted

            // Check for cancellation.
            if fdIsSet(cancelReadFD, set: &readSet) { break }

            // Read available bytes.
            let n = Foundation.read(fileDescriptor, &buf, bufSize)
            if n <= 0 { break }

            let data = leftover + Array(buf[0..<n])
            let canHaveMore = n == bufSize

            let (messages, consumed) = InputParser.parse(buffer: data, canHaveMoreData: canHaveMore)
            for msg in messages {
                continuation.yield(msg)
            }

            leftover = consumed < data.count ? Array(data[consumed...]) : []
        }

        finish()
    }

    /// Mark the reader finished and release resources, at most once.
    private func finish() {
        lock.lock()
        guard state != .finished else {
            lock.unlock()
            return
        }
        state = .finished
        lock.unlock()
        releaseResources()
    }
}

// MARK: - fd_set helpers

// Swift doesn't expose the fd_set bit-manipulation macros directly, so we
// implement them manually using the underlying storage.

private func fdZero(_ set: inout fd_set) {
    _ = withUnsafeMutableBytes(of: &set) { ptr in
        ptr.initializeMemory(as: UInt8.self, repeating: 0)
    }
}

private func fdSet(_ fd: Int32, set: inout fd_set) {
    let intOffset = Int(fd) / 32
    let bitOffset = Int(fd) % 32
    withUnsafeMutableBytes(of: &set) { ptr in
        let words = ptr.bindMemory(to: UInt32.self)
        words[intOffset] |= UInt32(1 << bitOffset)
    }
}

private func fdIsSet(_ fd: Int32, set: inout fd_set) -> Bool {
    let intOffset = Int(fd) / 32
    let bitOffset = Int(fd) % 32
    return withUnsafeMutableBytes(of: &set) { ptr -> Bool in
        let words = ptr.bindMemory(to: UInt32.self)
        return (words[intOffset] & UInt32(1 << bitOffset)) != 0
    }
}
