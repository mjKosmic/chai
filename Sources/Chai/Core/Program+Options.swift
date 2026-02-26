extension Program {
    /// Configuration options for a ``Program``.
    public enum Option: Sendable {
        /// Start the program in the alternate screen buffer (full-window mode).
        case withAltScreen
        /// Set a custom frame rate for the renderer (1–120 FPS).
        case withFPS(Int)
        /// Set the terminal window title on startup.
        case withWindowTitle(String)
        /// Disable the SIGINT / SIGTERM signal handler.
        ///
        /// Use this if you want to handle OS signals yourself.
        case withoutSignalHandler
        /// Attach a logger for internal diagnostics.
        ///
        /// Since Chai owns stdout (the terminal), debug output must be directed
        /// elsewhere. Use ``FileLogger`` to write to a file, or implement
        /// ``ChaiLogger`` for a custom destination.
        ///
        /// ```swift
        /// let logger = try FileLogger(path: "/tmp/chai.log")
        /// let program = Program(model, options: .withLogger(logger))
        /// ```
        case withLogger(any ChaiLogger)
    }
}
