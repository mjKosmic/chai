#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

import Foundation

/// The Chai runtime. Creates a terminal UI from a ``Model``.
///
/// `Program` manages the full lifecycle of a TUI application:
/// - Puts the terminal into raw mode.
/// - Starts the framerate-based renderer.
/// - Reads keyboard input asynchronously.
/// - Runs the Model-Update-View event loop.
/// - Restores the terminal on exit.
///
/// ## Usage
///
/// ```swift
/// @main struct App {
///     static func main() async throws {
///         try await Program(MyModel(), options: .withAltScreen).run()
///     }
/// }
/// ```
///
/// ## External Message Injection
///
/// Use ``send(_:)`` to inject messages from outside the event loop:
///
/// ```swift
/// let program = Program(MyModel())
/// // Start the program on another task.
/// Task { try await program.run() }
/// // Inject a message from the outside.
/// program.send(MyExternalEvent())
/// ```
///
/// ## Event Filtering
///
/// Use ``init(_:options:filter:)`` to intercept messages before they
/// reach the model:
///
/// ```swift
/// let program = Program(MyModel(), filter: { model, msg in
///     if msg is QuitMsg && model.hasUnsavedChanges {
///         return ConfirmQuitMsg()  // Replace with a confirmation
///     }
///     return msg
/// })
/// ```
public struct Program<M: Model>: Sendable {

    // MARK: - Properties

    private let initialModel: M
    private let options: [Option]
    private let channel: MessageChannel
    private let messageFilter: (@Sendable (M, any Message) -> (any Message)?)?

    // MARK: - Init

    /// Create a new program with the given initial model and options.
    ///
    /// - Parameters:
    ///   - model: The initial model state.
    ///   - options: Zero or more ``Program.Option`` values.
    public init(_ model: M, options: Option...) {
        self.initialModel = model
        self.options = options
        self.channel = MessageChannel()
        self.messageFilter = nil
    }

    /// Create a new program with an event filter.
    ///
    /// The filter is called for every non-internal message before it reaches
    /// ``Model/update(_:)``. Return the message (possibly transformed) to
    /// deliver it, or `nil` to suppress it entirely.
    ///
    /// - Parameters:
    ///   - model: The initial model state.
    ///   - options: An array of ``Program.Option`` values.
    ///   - filter: A closure that can intercept, transform, or suppress messages.
    public init(
        _ model: M,
        options: [Option] = [],
        filter: @Sendable @escaping (M, any Message) -> (any Message)?
    ) {
        self.initialModel = model
        self.options = options
        self.channel = MessageChannel()
        self.messageFilter = filter
    }

    // MARK: - External message injection

    /// Inject a message into the program's event loop from outside.
    ///
    /// This method is thread-safe and can be called from any context.
    /// Messages sent before ``run()`` starts are buffered and delivered
    /// once the event loop begins. Messages sent after the program exits
    /// are silently dropped.
    ///
    /// - Parameter msg: The message to inject.
    public func send(_ msg: any Message) {
        channel.yield(msg)
    }

    // MARK: - Run

    /// Start the program and block until it exits.
    ///
    /// - Returns: The final model state after the program exits.
    /// - Throws: Any error that caused the program to terminate abnormally.
    @discardableResult
    public func run() async throws -> M {
        let runner = ProgramRunner(
            model: initialModel,
            options: options,
            channel: channel,
            filter: messageFilter
        )
        return try await runner.run()
    }
}

// MARK: - ProgramRunner (internal)

/// The internal implementation of the program event loop.
///
/// Separated from `Program` so the public API stays clean and the runner
/// can hold mutable state without `Program` needing to be a class.
private final class ProgramRunner<M: Model>: Sendable {

    // MARK: - State

    private let initialModel: M
    private let options: [Program<M>.Option]

    private let terminal: Terminal
    private let renderer: Renderer
    private let inputReader: InputReader

    /// Shared message channel (owned by ``Program``, shared here).
    private let channel: MessageChannel

    /// Optional event filter applied before messages reach the model.
    private let filter: (@Sendable (M, any Message) -> (any Message)?)?

    /// Optional logger for internal diagnostics.
    private let logger: (any ChaiLogger)?

    // MARK: - Init

    init(
        model: M,
        options: [Program<M>.Option],
        channel: MessageChannel,
        filter: (@Sendable (M, any Message) -> (any Message)?)?
    ) {
        self.initialModel = model
        self.options = options
        self.channel = channel
        self.filter = filter

        self.terminal = Terminal()
        self.inputReader = InputReader(fileDescriptor: STDIN_FILENO)

        let fps = options.compactMap { if case .withFPS(let f) = $0 { return f } else { return nil } }.first
            ?? Renderer.defaultFPS
        self.renderer = Renderer(terminal: terminal, fps: fps)

        self.logger = options.compactMap { option -> (any ChaiLogger)? in
            if case .withLogger(let l) = option { return l } else { return nil }
        }.first
    }

    // MARK: - Run

    func run() async throws -> M {
        var model = initialModel

        await logger?.log(.debug, "Program starting")

        // ── Terminal setup ──────────────────────────────────────────────────
        try terminal.enableRawMode()

        // Ensure terminal is always restored, even on thrown errors.
        defer {
            terminal.disableRawMode()
        }

        // ── Renderer startup ────────────────────────────────────────────────
        if options.contains(where: { if case .withAltScreen = $0 { return true } else { return false } }) {
            await renderer.enterAltScreen()
        }
        if let title = options.compactMap({ if case .withWindowTitle(let t) = $0 { return t } else { return nil } }).first {
            await renderer.setWindowTitle(title)
        }
        await renderer.start()

        // ── Initial window size ─────────────────────────────────────────────
        let (w, h) = terminal.size()
        await renderer.setSize(width: w, height: h)
        send(WindowSizeMsg(width: w, height: h))
        await logger?.log(.debug, "Initial terminal size: \(w)x\(h)")

        // ── Signal handling ─────────────────────────────────────────────────
        let signalHandler: SignalHandler?
        if !options.contains(where: { if case .withoutSignalHandler = $0 { return true } else { return false } }) {
            signalHandler = SignalHandler { [weak self] msg in
                self?.send(msg)
            }
            signalHandler?.start()
        } else {
            signalHandler = nil
        }

        // ── Input reader ────────────────────────────────────────────────────
        inputReader.start()

        // Forward input messages into the main message stream.
        let inputTask = Task { [weak self] in
            guard let self else { return }
            for await msg in self.inputReader.messages {
                self.send(msg)
            }
        }

        // ── Init command ────────────────────────────────────────────────────
        if let initCmd = model.initialize() {
            execute(initCmd)
        }

        // ── Initial render ──────────────────────────────────────────────────
        await renderer.write(model.view())
        await renderer.flush()

        await logger?.log(.debug, "Event loop started")

        // ── Event loop ──────────────────────────────────────────────────────
        eventLoop: for await msg in channel.stream {
            // Handle renderer-level messages first.
            await handleRendererMessage(msg)

            // Internal messages (RepaintMsg, PrintLineMsg, WindowResizeSignalMsg,
            // etc.) are handled above and should not reach the model or trigger
            // unnecessary view() calls.
            if msg is InternalMessage { continue }

            // Apply event filter if one was provided.
            var deliveredMsg = msg
            if let filter = self.filter {
                guard let transformed = filter(model, msg) else {
                    await logger?.log(.debug, "Message filtered out: \(type(of: msg))")
                    continue
                }
                deliveredMsg = transformed
            }

            // Deliver to model.
            let cmd = model.update(deliveredMsg)

            // Render updated view.
            await renderer.write(model.view())

            // Execute any returned command.
            if let cmd = cmd {
                if case .quit = cmd {
                    await logger?.log(.debug, "Quit command received")
                    break eventLoop
                }
                execute(cmd)
            }

            // Check for quit message.
            if deliveredMsg is QuitMsg {
                await logger?.log(.debug, "QuitMsg received")
                break eventLoop
            }
        }

        // ── Shutdown ────────────────────────────────────────────────────────
        await logger?.log(.debug, "Shutting down")

        inputTask.cancel()
        inputReader.stop()
        signalHandler?.stop()
        channel.finish()

        await renderer.stop()

        // Exit alt screen if it was active (whether set via program option
        // or declaratively via ViewOutput).
        if await renderer.altScreenActive {
            await renderer.exitAltScreen()
        }

        // Restore cursor visibility and shape.
        terminal.write(ANSI.showCursor)
        terminal.write(ANSI.resetCursorShape)

        return model
    }

    // MARK: - Message dispatch

    /// Send a message into the event loop.
    func send(_ msg: any Message) {
        channel.yield(msg)
    }

    // MARK: - Command execution

    /// Execute a command, sending any resulting messages back into the loop.
    private func execute(_ command: Command) {
        switch command {
        case .perform(let work):
            Task { [weak self] in
                let msg = await work()
                self?.send(msg)
            }

        case .batch(let cmds):
            for cmd in cmds { execute(cmd) }

        case .sequence(let cmds):
            guard !cmds.isEmpty else { return }
            Task { [weak self] in
                for cmd in cmds {
                    guard let self else { return }
                    // For sequence, we execute each command and wait for its
                    // message before proceeding to the next.
                    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                        switch cmd {
                        case .perform(let work):
                            Task {
                                let msg = await work()
                                self.send(msg)
                                cont.resume()
                            }
                        default:
                            self.execute(cmd)
                            cont.resume()
                        }
                    }
                }
            }

        case .quit:
            send(QuitMsg())

        case .setWindowTitle(let title):
            Task { [renderer] in
                await renderer.setWindowTitle(title)
            }

        case .clearScreen:
            Task { [logger] in await logger?.log(.debug, "Clearing screen") }
            Task { [renderer] in
                await renderer.clearScreen()
            }

        case .requestWindowSize:
            let (w, h) = terminal.size()
            Task { [logger] in await logger?.log(.debug, "Window size requested: \(w)x\(h)") }
            send(WindowSizeMsg(width: w, height: h))
        }
    }

    // MARK: - Renderer message handling

    fileprivate func handleRendererMessage(_ msg: any Message) async {
        switch msg {
        case is WindowResizeSignalMsg:
            let (w, h) = terminal.size()
            await renderer.setSize(width: w, height: h)
            send(WindowSizeMsg(width: w, height: h))
            await logger?.log(.debug, "Window resized: \(w)x\(h)")

        case let sz as WindowSizeMsg:
            await renderer.setSize(width: sz.width, height: sz.height)

        case is RepaintMsg:
            await renderer.repaint()

        case let pl as PrintLineMsg:
            await renderer.println(pl.body)

        default:
            break
        }
    }
}

// MARK: - Signal Handler

/// Listens for SIGWINCH (terminal resize) and SIGINT/SIGTERM (quit signals)
/// and forwards them as Chai messages.
///
/// Remains `@unchecked Sendable` solely because `DispatchSourceSignal` is not
/// annotated as `Sendable` in the Swift Dispatch overlay, even though GCD
/// dispatch sources are inherently thread-safe. All stored properties are `let`.
private final class SignalHandler: @unchecked Sendable {

    private let handler: @Sendable (any Message) -> Void
    private let sources: [DispatchSourceSignal]

    init(handler: @Sendable @escaping (any Message) -> Void) {
        self.handler = handler

        let winchSource = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .global())
        winchSource.setEventHandler {
            handler(WindowResizeSignalMsg())
        }

        let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        intSource.setEventHandler {
            handler(QuitMsg())
        }

        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
        termSource.setEventHandler {
            handler(QuitMsg())
        }

        self.sources = [winchSource, intSource, termSource]
    }

    func start() {
        // Ignore default signal disposition so we can handle them ourselves.
        signal(SIGWINCH, SIG_IGN)
        signal(SIGINT,   SIG_IGN)
        signal(SIGTERM,  SIG_IGN)
        sources.forEach { $0.resume() }
    }

    func stop() {
        sources.forEach { $0.cancel() }
        signal(SIGWINCH, SIG_DFL)
        signal(SIGINT,   SIG_DFL)
        signal(SIGTERM,  SIG_DFL)
    }
}

/// Internal sentinel message sent when SIGWINCH fires.
/// The runner resolves the actual size and converts it to a `WindowSizeMsg`.
private struct WindowResizeSignalMsg: InternalMessage {}


