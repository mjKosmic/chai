import Foundation

/// Represents an asynchronous side-effect that your model can trigger.
///
/// Commands are returned from ``Model/update(_:)`` and ``Model/initialize()``.
/// The Chai runtime executes them and delivers the resulting ``Message``
/// back to your model.
///
/// ## Creating Commands
///
/// Use the static factory methods for the most common cases:
///
/// ```swift
/// // Quit the program
/// return .quit
///
/// // Perform async work and send the result as a message
/// return .perform {
///     let data = try? await URLSession.shared.data(from: url)
///     return DataLoaded(data: data)
/// }
///
/// // Run two commands concurrently
/// return .batch([loadUsers, loadPosts])
///
/// // Run two commands one after the other
/// return .sequence([saveFile, showConfirmation])
///
/// // Fire a message after a delay
/// return .tick(.seconds(1)) { _ in RefreshMsg() }
/// ```
public enum Command: Sendable {

    // MARK: - Core cases

    /// Execute an async closure and deliver its return value as a message.
    case perform(@Sendable () async -> any Message)

    /// Run multiple commands concurrently. Messages arrive in an unspecified order.
    case batch([Command])

    /// Run commands one at a time, in order.
    ///
    /// Each command's message is delivered to the model before the next
    /// command starts.
    case sequence([Command])

    /// Signal the program to exit gracefully.
    case quit

    /// Set the terminal window title.
    case setWindowTitle(String)

    // MARK: - Convenience factories

    /// Deliver a message after the given duration has elapsed.
    ///
    /// - Parameters:
    ///   - duration: How long to wait.
    ///   - map: Closure that converts the fire time into a ``Message``.
    public static func tick(
        _ duration: Duration,
        map: @Sendable @escaping (ContinuousClock.Instant) -> any Message
    ) -> Command {
        .perform {
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: duration)
            try? await Task.sleep(until: deadline, clock: clock)
            return map(clock.now)
        }
    }

    /// Deliver a message at a wall-clock interval aligned to the system clock.
    ///
    /// Unlike ``tick(_:map:)``, this aligns to the next multiple of `duration`
    /// on the wall clock (e.g. every full second).
    ///
    /// - Parameters:
    ///   - duration: The interval between ticks.
    ///   - map: Closure that converts the fire time into a ``Message``.
    public static func every(
        _ duration: Duration,
        map: @Sendable @escaping (ContinuousClock.Instant) -> any Message
    ) -> Command {
        .perform {
            // Align to the next wall-clock boundary.
            let now = Date()
            let interval = duration.timeInterval
            let nextBoundary = (now.timeIntervalSinceReferenceDate / interval).rounded(.up) * interval
            let delay = nextBoundary - now.timeIntervalSinceReferenceDate
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            return map(ContinuousClock().now)
        }
    }

    /// Print a line above the live view (persists across renders).
    ///
    /// Has no effect when the alt screen is active.
    public static func println(_ text: String) -> Command {
        .perform { PrintLineMsg(body: text) }
    }
}

// MARK: - Duration helper

private extension Duration {
    var timeInterval: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
