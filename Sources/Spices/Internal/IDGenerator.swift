import Foundation

/// A thread-safe, monotonically incrementing integer counter
/// for generating unique component instance IDs.
///
/// Each component type (Spinner, Timer, etc.) owns its own generator
/// to produce IDs that gate internal tick messages, preventing stale
/// ticks from affecting a component that has been replaced or
/// reconfigured.
final class IDGenerator: @unchecked Sendable {
    private var _value: Int
    private let _lock = NSLock()

    init(_ initial: Int = 0) {
        _value = initial
    }

    /// Returns the next unique ID.
    func next() -> Int {
        _lock.lock()
        defer { _lock.unlock() }
        _value += 1
        return _value
    }
}
