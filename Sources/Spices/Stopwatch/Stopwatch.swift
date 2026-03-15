import Chai

// MARK: - Stopwatch messages

/// Delivered on each stopwatch tick.
public struct StopwatchTickMsg: Message {
    /// The stopwatch's unique identifier.
    public let id: Int
    /// Internal generation tag to reject stale ticks.
    let tag: Int
}

// MARK: - ID generation

private let _stopwatchIDGenerator = IDGenerator()

// MARK: - Stopwatch

/// An elapsed-time counter that ticks upward at a configurable interval.
///
/// ```swift
/// var stopwatch = Stopwatch(interval: .seconds(1))
///
/// // In initialize():
/// stopwatch.initialize()  // starts counting
///
/// // In view():
/// "Elapsed: " + stopwatch.view()  // e.g. "1m23s"
/// ```
public struct Stopwatch: Sendable {
    /// The interval between ticks.
    public var interval: Duration

    // MARK: Private state

    private let _id: Int
    private var _tag: Int
    private var _elapsed: Duration
    private var _running: Bool

    // MARK: - Initializer

    /// Creates a new stopwatch.
    ///
    /// - Parameter interval: The tick interval. Defaults to 1 second.
    public init(interval: Duration = .seconds(1)) {
        self.interval = interval
        self._id = _stopwatchIDGenerator.next()
        self._tag = 0
        self._elapsed = .zero
        self._running = false
    }

    // MARK: - ELM interface

    /// Starts the stopwatch and returns the first tick command.
    public mutating func initialize() -> Command? {
        start()
    }

    /// Handles tick messages.
    public mutating func update(_ msg: any Message) -> Command? {
        switch msg {
        case let tick as StopwatchTickMsg where tick.id == _id && tick.tag == _tag:
            guard _running else { return nil }
            _elapsed += interval
            return tickCommand()

        default:
            return nil
        }
    }

    /// Renders the elapsed time as a human-readable string.
    public func view() -> ViewOutput {
        ViewOutput(formatDuration(_elapsed))
    }

    // MARK: - Control

    /// The total elapsed time.
    public var elapsed: Duration { _elapsed }

    /// Whether the stopwatch is currently running.
    public var isRunning: Bool { _running }

    /// The unique identifier for this stopwatch instance.
    public var id: Int { _id }

    /// Starts the stopwatch and returns a tick command.
    @discardableResult
    public mutating func start() -> Command? {
        _running = true
        _tag += 1
        return tickCommand()
    }

    /// Stops the stopwatch.
    @discardableResult
    public mutating func stop() -> Command? {
        _running = false
        _tag += 1
        return nil
    }

    /// Toggles between running and stopped.
    @discardableResult
    public mutating func toggle() -> Command? {
        if _running {
            return stop()
        } else {
            return start()
        }
    }

    /// Resets the elapsed time to zero without stopping.
    @discardableResult
    public mutating func reset() -> Command? {
        _elapsed = .zero
        _tag += 1
        if _running {
            return tickCommand()
        }
        return nil
    }

    // MARK: - Private

    private func tickCommand() -> Command? {
        let id = self._id
        let tag = self._tag
        let interval = self.interval
        return .tick(interval) { _ in
            StopwatchTickMsg(id: id, tag: tag)
        }
    }
}
