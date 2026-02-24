#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

import Foundation

// MARK: - ProgramOption

/// Configuration options for a ``Program``.
public enum ProgramOption: Sendable {
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
}

// MARK: - Program

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
public struct Program<M: Model>: Sendable {

    // MARK: - Properties

    private let initialModel: M
    private let options: [ProgramOption]

    // MARK: - Init

    /// Create a new program with the given initial model and options.
    ///
    /// - Parameters:
    ///   - model: The initial model state.
    ///   - options: Zero or more ``ProgramOption`` values.
    public init(_ model: M, options: ProgramOption...) {
        self.initialModel = model
        self.options = options
    }

    // MARK: - Run

    /// Start the program and block until it exits.
    ///
    /// - Returns: The final model state after the program exits.
    /// - Throws: Any error that caused the program to terminate abnormally.
    @discardableResult
    public func run() async throws -> M {
        let runner = ProgramRunner(model: initialModel, options: options)
        return try await runner.run()
    }
}

// MARK: - ProgramRunner (internal)

/// The internal implementation of the program event loop.
///
/// Separated from `Program` so the public API stays clean and the runner
/// can hold mutable state without `Program` needing to be a class.
private final class ProgramRunner<M: Model>: @unchecked Sendable {

    // MARK: - State

    private var model: M
    private let options: [ProgramOption]

    private let terminal: Terminal
    private let renderer: Renderer
    private let inputReader: InputReader

    /// Channel through which all messages flow into the event loop.
    private let messageContinuation: AsyncStream<any Message>.Continuation
    private let messageStream: AsyncStream<any Message>

    // MARK: - Init

    init(model: M, options: [ProgramOption]) {
        self.model = model
        self.options = options
        self.terminal = Terminal()
        self.inputReader = InputReader(fileDescriptor: STDIN_FILENO)

        let fps = options.compactMap { if case .withFPS(let f) = $0 { return f } else { return nil } }.first
            ?? Renderer.defaultFPS
        self.renderer = Renderer(terminal: terminal, fps: fps)

        var cont: AsyncStream<any Message>.Continuation!
        self.messageStream = AsyncStream { cont = $0 }
        self.messageContinuation = cont
    }

    // MARK: - Run

    func run() async throws -> M {
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

        // ── Event loop ──────────────────────────────────────────────────────
        eventLoop: for await msg in messageStream {
            // Handle renderer-level messages first.
            await handleRendererMessage(msg)

            // Deliver to model.
            let cmd = model.update(msg)

            // Render updated view.
            await renderer.write(model.view())

            // Execute any returned command.
            if let cmd = cmd {
                if case .quit = cmd {
                    break eventLoop
                }
                execute(cmd)
            }

            // Check for quit message.
            if msg is QuitMsg { break eventLoop }
        }

        // ── Shutdown ────────────────────────────────────────────────────────
        inputTask.cancel()
        inputReader.stop()
        signalHandler?.stop()

        await renderer.stop()

        if options.contains(where: { if case .withAltScreen = $0 { return true } else { return false } }) {
            await renderer.exitAltScreen()
        }

        // Restore cursor visibility.
        terminal.write(ANSI.showCursor)

        return model
    }

    // MARK: - Message dispatch

    /// Send a message into the event loop.
    func send(_ msg: any Message) {
        messageContinuation.yield(msg)
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
            Task { [weak self] in
                await self?.renderer.setWindowTitle(title)
            }
        }
    }

    // MARK: - Renderer message handling

    fileprivate func handleRendererMessage(_ msg: any Message) async {
        switch msg {
        case is WindowResizeSignalMsg:
            let (w, h) = terminal.size()
            await renderer.setSize(width: w, height: h)
            send(WindowSizeMsg(width: w, height: h))

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
private final class SignalHandler: @unchecked Sendable {

    private let handler: @Sendable (any Message) -> Void
    private var sources: [DispatchSourceSignal] = []

    init(handler: @Sendable @escaping (any Message) -> Void) {
        self.handler = handler
    }

    func start() {
        // Ignore default signal disposition so we can handle them ourselves.
        signal(SIGWINCH, SIG_IGN)
        signal(SIGINT,   SIG_IGN)
        signal(SIGTERM,  SIG_IGN)

        let winchSource = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .global())
        winchSource.setEventHandler { [weak self] in
            // Re-query terminal size and send a WindowSizeMsg.
            // We can't access `terminal` here directly, so we send a sentinel
            // that the runner will resolve.
            self?.handler(WindowResizeSignalMsg())
        }
        winchSource.resume()
        sources.append(winchSource)

        let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        intSource.setEventHandler { [weak self] in
            self?.handler(QuitMsg())
        }
        intSource.resume()
        sources.append(intSource)

        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
        termSource.setEventHandler { [weak self] in
            self?.handler(QuitMsg())
        }
        termSource.resume()
        sources.append(termSource)
    }

    func stop() {
        sources.forEach { $0.cancel() }
        sources = []
        signal(SIGWINCH, SIG_DFL)
        signal(SIGINT,   SIG_DFL)
        signal(SIGTERM,  SIG_DFL)
    }
}

/// Internal sentinel message sent when SIGWINCH fires.
/// The runner resolves the actual size and converts it to a `WindowSizeMsg`.
private struct WindowResizeSignalMsg: Message {}


