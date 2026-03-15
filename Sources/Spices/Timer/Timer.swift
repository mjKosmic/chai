import Chai

// MARK: - Timer messages

/// Delivered on each timer tick with the remaining timeout.
public struct TimerTickMsg: Message {
    /// The timer's unique identifier.
    public let id: Int
    /// The remaining duration at the time of the tick.
    public let timeout: Duration
    /// Internal generation tag to reject stale ticks.
    let tag: Int
}

/// Delivered when the timer reaches zero.
public struct TimerTimeoutMsg: Message {
    /// The timer's unique identifier.
    public let id: Int
}

/// Internal message for starting or stopping the timer.
struct TimerStartStopMsg: Message {
    let id: Int
    let running: Bool
}

// MARK: - ID generation

private let _timerIDGenerator = IDGenerator()

// MARK: - Timer

/// A countdown timer that ticks at a configurable interval.
///
/// The timer counts down from ``timeout`` and emits ``TimerTickMsg``
/// on each tick. When the remaining time reaches zero, a
/// ``TimerTimeoutMsg`` is delivered.
///
/// ```swift
/// var timer = SpiceTimer(timeout: .seconds(30), interval: .seconds(1))
///
/// // In initialize():
/// timer.initialize()  // starts the countdown
///
/// // In update():
/// if let tick = msg as? TimerTickMsg {
///     // Update display with tick.timeout
/// }
/// if msg is TimerTimeoutMsg {
///     // Timer finished!
/// }
/// ```
public struct SpiceTimer: Sendable {
    /// The remaining duration. Decreases on each tick.
    public private(set) var timeout: Duration

    /// The interval between ticks.
    public var interval: Duration

    // MARK: Private state

    private let _id: Int
    private var _tag: Int
    private var _running: Bool

    // MARK: - Initializer

    /// Creates a new countdown timer.
    ///
    /// - Parameters:
    ///   - timeout: The total countdown duration.
    ///   - interval: How often to tick. Defaults to 1 second.
    public init(timeout: Duration, interval: Duration = .seconds(1)) {
        self.timeout = timeout
        self.interval = interval
        self._id = _timerIDGenerator.next()
        self._tag = 0
        self._running = false
    }

    // MARK: - ELM interface

    /// Starts the timer and returns the first tick command.
    public mutating func initialize() -> Command? {
        start()
    }

    /// Handles tick and start/stop messages.
    public mutating func update(_ msg: any Message) -> Command? {
        switch msg {
        case let startStop as TimerStartStopMsg where startStop.id == _id:
            _running = startStop.running
            _tag += 1
            if _running {
                return tickCommand()
            }
            return nil

        case let tick as TimerTickMsg where tick.id == _id && tick.tag == _tag:
            guard _running else { return nil }

            if timeout <= .zero {
                _running = false
                return .perform { [id = _id] in TimerTimeoutMsg(id: id) }
            }

            // Decrease timeout by the interval
            timeout -= interval
            if timeout < .zero { timeout = .zero }

            if timeout <= .zero {
                _running = false
                return .perform { [id = _id] in TimerTimeoutMsg(id: id) }
            }

            return tickCommand()

        default:
            return nil
        }
    }

    /// Renders the remaining time as a human-readable string.
    public func view() -> ViewOutput {
        ViewOutput(formatDuration(timeout))
    }

    // MARK: - Control

    /// Whether the timer is currently running.
    public var isRunning: Bool { _running }

    /// Whether the timer has reached zero.
    public var isTimedOut: Bool { timeout <= .zero }

    /// The unique identifier for this timer instance.
    public var id: Int { _id }

    /// Starts the timer and returns a command to begin ticking.
    @discardableResult
    public mutating func start() -> Command? {
        _running = true
        _tag += 1
        return tickCommand()
    }

    /// Stops the timer.
    @discardableResult
    public mutating func stop() -> Command? {
        _running = false
        _tag += 1
        return nil
    }

    /// Toggles the timer between running and stopped.
    @discardableResult
    public mutating func toggle() -> Command? {
        if _running {
            return stop()
        } else {
            return start()
        }
    }

    // MARK: - Private

    private func tickCommand() -> Command? {
        let id = self._id
        let tag = self._tag
        let interval = self.interval
        let timeout = self.timeout
        return .tick(interval) { _ in
            TimerTickMsg(id: id, timeout: timeout, tag: tag)
        }
    }
}

// MARK: - Duration formatting

/// Formats a `Duration` as a human-readable string (e.g. "2m30s", "45s").
func formatDuration(_ duration: Duration) -> String {
    let (seconds, attoseconds) = duration.components
    let totalSeconds = max(0, seconds)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let secs = totalSeconds % 60
    let millis = attoseconds / 1_000_000_000_000_000

    if hours > 0 {
        return String(format: "%dh%dm%ds", hours, minutes, secs)
    } else if minutes > 0 {
        return String(format: "%dm%ds", minutes, secs)
    } else if millis > 0 && totalSeconds == 0 {
        return String(format: "%dms", millis)
    } else {
        return String(format: "%ds", secs)
    }
}
