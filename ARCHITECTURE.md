# Chai Architecture

Chai is a Swift-native terminal UI (TUI) framework inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea). It implements the **Elm Architecture** (Model-Update-View) using modern Swift concurrency — `async`/`await`, actors, `AsyncStream`, and structured `Task`s — with zero external dependencies.

The repository is a monorepo containing three libraries:

| Library | Purpose | Dependencies |
|---------|---------|--------------|
| **Chai** | Core TUI framework (Elm Architecture runtime, input handling, rendering) | None |
| **Latte** | Layout and styling primitives (borders, padding, alignment, wrapping, sizing) | None |
| **Spices** | Pre-built interactive components (text input, lists, tables, spinners, timers, etc.) | Chai |

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [High-Level Architecture](#high-level-architecture)
3. [The Elm Architecture in Chai](#the-elm-architecture-in-chai)
4. [Component Reference](#component-reference)
   - [Model](#model)
   - [Message](#message)
   - [Command](#command)
   - [Program / ProgramRunner](#program--programrunner)
   - [Terminal](#terminal)
   - [InputReader](#inputreader)
   - [InputParser](#inputparser)
   - [Renderer](#renderer)
   - [ANSICodes](#ansicodes)
   - [SignalHandler](#signalhandler)
5. [Latte — Layout & Styling Library](#latte--layout--styling-library)
6. [Spices — Component Library](#spices--component-library)
7. [Data Flow](#data-flow)
8. [Concurrency Model](#concurrency-model)
9. [Input Pipeline](#input-pipeline)
10. [Rendering Pipeline](#rendering-pipeline)
11. [Command Execution](#command-execution)
12. [Signal Handling](#signal-handling)
13. [Lifecycle](#lifecycle)
14. [Testing Strategy](#testing-strategy)
15. [Package Layout](#package-layout)
16. [Design Decisions & Trade-offs](#design-decisions--trade-offs)

---

## Design Philosophy

| Principle | How it is applied |
|-----------|-------------------|
| **Value semantics for state** | `Model` is a `Sendable` value type (`struct`). `update` is `mutating`. No shared mutable state in user code. |
| **Unidirectional data flow** | Messages flow in → model updates → view renders. No callbacks, no delegates. |
| **Zero dependencies** | Only Swift stdlib, Foundation, and POSIX APIs (`termios`, `ioctl`, `select`). |
| **Testability** | I/O is behind protocols (`TerminalOutput`). The parser and renderer are independently testable without a real TTY. |
| **Cross-platform** | Darwin and Linux are supported via conditional imports (`#if canImport(Darwin)`). |
| **Swift 6 concurrency safety** | `StrictConcurrency` is enabled. All shared state is either actor-isolated, `Sendable`, or confined to a single thread. |

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Program<M>                           │
│                                                             │
│  ┌──────────────┐    messages    ┌──────────────────────┐  │
│  │ InputReader  │ ─────────────► │                      │  │
│  │ (bg Thread)  │                │    Event Loop        │  │
│  └──────────────┘                │  (AsyncStream<Msg>)  │  │
│                                  │                      │  │
│  ┌──────────────┐    messages    │  model.update(msg)   │  │
│  │SignalHandler │ ─────────────► │       │              │  │
│  │(DispatchSrc) │                │       ▼              │  │
│  └──────────────┘                │  model.view()        │  │
│                                  │       │              │  │
│  ┌──────────────┐    commands    │       ▼              │  │
│  │   Command    │ ◄──────────────│  execute(cmd)        │  │
│  │  execution   │                │                      │  │
│  │  (Tasks)     │ ─── msgs ─────►│                      │  │
│  └──────────────┘                └──────────┬───────────┘  │
│                                             │ ViewOutput   │
│                                             ▼              │
│                                  ┌──────────────────────┐  │
│                                  │   Renderer (actor)   │  │
│                                  │   60 FPS diff flush  │  │
│                                  └──────────┬───────────┘  │
│                                             │ ANSI bytes   │
│                                             ▼              │
│                                  ┌──────────────────────┐  │
│                                  │  Terminal (stdout)   │  │
│                                  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## The Elm Architecture in Chai

Chai's runtime is a direct implementation of the Elm Architecture loop:

```
initialize() ──► Command?
                    │
                    ▼
             ┌─────────────┐
  Message ──►│   update()  │──► Command?
             └──────┬──────┘
                    │
                    ▼
                 view() ──► ViewOutput ──► Renderer
```

### The three model methods

```swift
public protocol Model: Sendable {
    func initialize() -> Command?
    mutating func update(_ msg: any Message) -> Command?
    func view() -> ViewOutput
}
```

- **`initialize()`** — called once at startup. Returns an optional `Command` for initial I/O (e.g. loading data, starting a timer).
- **`update(_ msg:)`** — called for every incoming `Message`. Mutates state and optionally returns a `Command` for further async work.
- **`view()`** — called after every `update`. Returns a `ViewOutput` containing the full UI as a string plus optional declarative terminal state (alt screen, window title, cursor visibility). ANSI escape codes are supported for colour and styling within the content string. Thanks to `ExpressibleByStringInterpolation` conformance, simple models can return a string literal directly.

The model is a **value type**. `ProgramRunner` holds the single authoritative copy and mutates it in-place on the event loop. There is no diffing of the model itself — `view()` is always called after every message.

---

## Component Reference

### Model

**File:** `Sources/Chai/Core/Model.swift`

The `Model` protocol is the only type users must implement. It carries three constraints:

- `Sendable` — the model must be safe to pass across concurrency boundaries (required because `Program` is generic over `M: Model` and `Program` itself is `Sendable`).
- `mutating func update` — enforces value semantics; the compiler prevents accidental shared-state bugs.
- No associated types — keeps the protocol simple and avoids type-erasure complexity at the call site.

`view()` returns a `ViewOutput`, which carries the rendered content string plus optional per-frame terminal state declarations (alt screen, window title, cursor visibility). `ViewOutput` conforms to `ExpressibleByStringInterpolation`, so simple models can return string literals directly. When terminal state fields are `nil`, the renderer preserves the current state — this maintains backward compatibility with program options like `.withAltScreen`.

---

### Message

**File:** `Sources/Chai/Core/Message.swift`

`Message` is a marker protocol:

```swift
public protocol Message: Sendable {}
```

Any `Sendable` type can be a message. The runtime delivers messages via an `AsyncStream<any Message>`, so the existential `any Message` is used throughout. Users cast to their concrete type in `update` with `as?`.

**Built-in messages:**

| Type | Delivered by | Purpose |
|------|-------------|---------|
| `KeyMsg` | `InputReader` | Keyboard event |
| `WindowSizeMsg` | `ProgramRunner` / `SignalHandler` | Terminal resize |
| `QuitMsg` | `SignalHandler` / `.quit` command | Graceful exit |
| `BatchMsg` *(internal)* | `Command.batch` | Run commands concurrently |
| `SequenceMsg` *(internal)* | `Command.sequence` | Run commands in order |
| `RepaintMsg` *(internal)* | `Command.repaint` | Force full repaint |
| `PrintLineMsg` *(internal)* | `Command.println` | Print above live view |
| `WindowResizeSignalMsg` *(internal)* | `SignalHandler` | SIGWINCH sentinel |

Internal messages are not exported. `WindowResizeSignalMsg` is a sentinel — `SignalHandler` cannot access `Terminal` directly, so it sends this sentinel and `ProgramRunner.handleRendererMessage` resolves the actual size via `ioctl`.

**`KeyMsg` structure:**

```swift
public struct KeyMsg: Message {
    public let type: KeyType      // what key
    public let runes: [Character] // printable characters (when type == .runes)
    public let alt: Bool          // Alt/Option modifier held
}
```

`KeyType` covers: printable runes, named keys (enter, tab, backspace, escape, space, arrows, home/end, page up/down, insert, delete), modifier combinations (Shift+arrow, Ctrl+arrow, Ctrl+Shift+arrow), Ctrl+letter, function keys F1–F20, and `.unknown`.

---

### Command

**File:** `Sources/Chai/Core/Command.swift`

`Command` is an enum of side-effects that the runtime knows how to execute:

```swift
public enum Command: Sendable {
    case perform(@Sendable () async -> any Message)
    case batch([Command])
    case sequence([Command])
    case quit
    case setWindowTitle(String)
}
```

| Case | Behaviour |
|------|-----------|
| `.perform(work)` | Spawns a `Task`, awaits `work()`, sends the returned `Message` back into the event loop. |
| `.batch(cmds)` | Executes all commands concurrently (each gets its own `Task`). Messages arrive in unspecified order. |
| `.sequence(cmds)` | Executes commands one at a time. Each command's message is delivered before the next command starts. |
| `.quit` | Sends a `QuitMsg` into the event loop, breaking the `eventLoop` label. |
| `.setWindowTitle(title)` | Calls `renderer.setWindowTitle` on the next iteration. |

**Convenience factories** (static methods that return `.perform`):

- `.tick(_ duration, map:)` — fires a message after a delay using `ContinuousClock`.
- `.every(_ duration, map:)` — fires a message aligned to the next wall-clock boundary.
- `.println(_ text)` — sends a `PrintLineMsg` that the renderer prints above the live view.

---

### Program / ProgramRunner

**File:** `Sources/Chai/Core/Program.swift`

`Program<M>` is the public entry point — a thin, `Sendable` struct that holds the initial model and options, then delegates to `ProgramRunner`:

```swift
public struct Program<M: Model>: Sendable {
    public init(_ model: M, options: ProgramOption...)
    public func run() async throws -> M
}
```

`ProgramRunner` is a `private final class` that owns all mutable runtime state. It is marked `@unchecked Sendable` because its mutable properties (`model`, `renderer`, etc.) are only ever accessed from the `async` event loop or from actor-isolated contexts.

**`ProgramOption`** values:

| Option | Effect |
|--------|--------|
| `.withAltScreen` | Enters the alternate screen buffer on start, exits on stop. |
| `.withFPS(n)` | Sets the renderer frame rate (1–120). Default: 60. |
| `.withWindowTitle(s)` | Sets the terminal window title on startup. |
| `.withoutSignalHandler` | Disables the built-in SIGINT/SIGTERM/SIGWINCH handler. |

**Event loop (simplified):**

```swift
eventLoop: for await msg in messageStream {
    await handleRendererMessage(msg)   // resize, repaint, println
    let cmd = model.update(msg)        // update model
    await renderer.write(model.view()) // queue new view
    if let cmd {
        if case .quit = cmd { break eventLoop }
        execute(cmd)
    }
    if msg is QuitMsg { break eventLoop }
}
```

The loop iterates over a single `AsyncStream<any Message>`. All event sources (keyboard, signals, command results) funnel into this one stream via `messageContinuation.yield(_:)`.

---

### Terminal

**File:** `Sources/Chai/Terminal/Terminal.swift`

`Terminal` is a `final class` that manages the raw TTY. It is not part of the public API.

**Responsibilities:**

1. **Raw mode** — `enableRawMode()` saves the current `termios`, then disables canonical mode (`ICANON`), echo (`ECHO`), signal generation (`ISIG`), extended input (`IEXTEN`), software flow control (`IXON`/`IXOFF`), and CR/NL translation (`ICRNL`/`INLCR`). Sets `VMIN=1`, `VTIME=0` so `read(2)` blocks until at least one byte is available. `disableRawMode()` restores the saved `termios`.

2. **Terminal size** — `size()` calls `ioctl(TIOCGWINSZ)` and returns `(width, height)` in columns and rows. Falls back to `(80, 24)` if the query fails.

3. **Output** — `write(_ string:)` converts the string to UTF-8 and writes it directly to the output file descriptor using `write(2)`, bypassing stdio buffering. Retries on short writes.

`Terminal` conforms to `TerminalOutput`, an internal protocol:

```swift
protocol TerminalOutput: AnyObject, Sendable {
    func write(_ string: String)
}
```

`Renderer` depends on `TerminalOutput`, not `Terminal` directly. Tests inject a `MockTerminalOutput` that captures written strings, making the renderer fully testable without a real TTY.

**`c_cc` access:** Swift does not expose `termios.c_cc` as an indexable array. The `VMIN`/`VTIME` slots are set via `withUnsafeMutableBytes(of: &t.c_cc)` using the integer constants `VMIN` and `VTIME` as byte offsets.

---

### InputReader

**File:** `Sources/Chai/Terminal/InputReader.swift`

`InputReader` bridges blocking POSIX I/O to Swift's async world.

**Why a background `Thread`, not a `Task`?**

Swift's cooperative thread pool must never block. `read(2)` on a TTY blocks until input arrives. Running it inside a `Task` would permanently stall one of the pool's threads. Instead, `InputReader` spawns a dedicated `Thread` (`chai.input-reader`, `.userInteractive` QoS) that blocks freely.

**Cancellation pipe:**

A POSIX pipe is created at init time. The read loop uses `select(2)` to wait on *both* stdin and the pipe's read end. When `stop()` is called, it writes a single byte to the pipe's write end, which unblocks `select` and causes the loop to exit cleanly.

**Read loop:**

```
select(stdin, cancelPipe)
    │
    ├─ cancelPipe readable → break
    │
    └─ stdin readable
           │
           read(stdin, buf, 256)
           │
           prepend leftover bytes
           │
           InputParser.parse(buffer:canHaveMoreData:)
           │
           yield each Message to AsyncStream
           │
           save unconsumed bytes as leftover
```

`canHaveMoreData` is `true` when the read filled the entire 256-byte buffer, signalling that more bytes may be waiting. The parser uses this to hold back incomplete escape sequences rather than reporting them as `.unknown`.

---

### InputParser

**File:** `Sources/Chai/Terminal/InputParser.swift`

`InputParser` is a pure `struct` with only `static` methods. It takes `[UInt8]` in and returns `([any Message], consumed: Int)` out — no I/O, no state.

**Parse priority (highest to lowest):**

1. **CSI sequences** — `ESC [` followed by parameter bytes and a final byte. Looked up in `csiTable`.
2. **SS3 sequences** — `ESC O` followed by one byte. Looked up in `ss3Table`.
3. **Lone ESC / Alt modifier** — bare `ESC` is either `.escape` or the Alt prefix for the next key.
4. **NUL byte** — `0x00` → `ctrl("@")`.
5. **Named control characters** — `0x08` (BS), `0x09` (HT/Tab), `0x0D` (CR/Enter), `0x1C`–`0x1F`. **Must be matched before the generic Ctrl range** to avoid `tab` being reported as `ctrl("i")` and `enter` as `ctrl("m")`.
6. **Generic Ctrl characters** — `0x01`–`0x1A` (excluding those above) → `ctrl("a")`–`ctrl("z")`.
7. **Space** — `0x20` → `.space`.
8. **Printable UTF-8** — one or more consecutive printable bytes decoded as UTF-8 runes, batched into a single `KeyMsg(type: .runes, runes: [...])`.

**Lookup tables:**

`csiTable` and `ss3Table` are `[String: KeyType]` dictionaries keyed on the raw ISO-Latin-1 string of the escape sequence. They cover:

- Arrow keys (plain, Shift, Alt, Ctrl, Ctrl+Shift)
- Home / End (multiple encodings for xterm, urxvt, Linux console)
- Page Up / Down, Insert, Delete
- Function keys F1–F20 (xterm, vt100, Linux console encodings)
- SS3 arrows and F1–F4

**Incomplete sequences:** If a sequence is not yet terminated and `canHaveMoreData` is `true`, the parser returns `consumed = 0` for that sequence. The caller (`InputReader`) prepends the unconsumed bytes to the next read.

---

### Renderer

**File:** `Sources/Chai/Renderer/Renderer.swift`

`Renderer` is a Swift `actor`. All state mutations are serialised by the actor's executor — no explicit locks are needed.

**State:**

| Property | Purpose |
|----------|---------|
| `pendingViewOutput` | The `ViewOutput` queued for the next flush |
| `lastContent` | The content string written in the previous flush |
| `lastLines` | Lines of the previous frame (for line-level diffing) |
| `linesRendered` | Line count of the last normal-screen render |
| `altLinesRendered` | Line count of the last alt-screen render |
| `altScreenActive` | Whether the alt screen buffer is active |
| `termWidth` / `termHeight` | Current terminal dimensions |
| `queuedLines` | Lines waiting to be printed above the live view |
| `cursorHidden` | Whether the cursor is currently hidden |
| `lastWindowTitle` | The last applied window title (for diffing) |
| `flushTask` | The background `Task` driving the render loop |

**Render loop:**

`start()` spawns a `Task` that sleeps for `1000/fps` milliseconds, then calls `flush()`, in a loop. Default is 60 FPS (≈16.7 ms per frame).

**`flush()` algorithm:**

1. If `pendingView == lastView`, skip (no change).
2. Split `pendingView` into lines. Clamp to `termHeight` if set.
3. Move cursor back to the start of the previously rendered content:
   - Alt screen: `ESC[H` (cursor home).
   - Normal screen: `ESC[{n}A` (cursor up `linesRendered - 1` lines).
4. Flush any queued `println` lines (normal screen only), each followed by `ESC[K` (erase to end of line) and `\r\n`.
5. For each line in the new frame:
   - If the line is identical to the corresponding line in `lastLines` and no `println` lines were flushed, emit only `\n` (skip the line).
   - Otherwise, truncate to `termWidth` (prevents terminal wrapping), write the line, then `ESC[K` (erase remainder of line).
6. If the previous frame had more lines than the new frame, emit `ESC[J` (erase screen below) to clear leftover content.
7. Park the cursor:
   - Alt screen: `ESC[{row};1H` (absolute position).
   - Normal screen: `\r` (start of last line).
8. Write the entire output string in one `terminal.write()` call.

**Alt screen:** `enterAltScreen()` writes `ESC[?1049h` (saves cursor, switches buffer, clears screen). `exitAltScreen()` writes `ESC[?1049l` (restores cursor, switches back).

**`println`:** Lines queued via `println(_:)` are prepended to the next flush output and persist above the live view. Has no effect when the alt screen is active (there is no "above" in a full-screen buffer).

---

### ANSICodes

**File:** `Sources/Chai/Terminal/ANSICodes.swift`

A namespace `enum` (no cases, cannot be instantiated) of ANSI/VT100 escape sequence string constants and factory functions. Used by `Renderer` and `Terminal`. Covers:

- Cursor visibility (`hideCursor`, `showCursor`)
- Cursor movement (`cursorHome`, `cursorUp`, `cursorDown`, `cursorPosition`)
- Erase operations (`eraseLineRight`, `eraseEntireLine`, `eraseScreenBelow`, `eraseEntireScreen`)
- Alternate screen (`enterAltScreen`, `exitAltScreen`)
- Scroll margins, line insertion
- Mouse tracking (button-event, all-motion, SGR extended)
- Bracketed paste, focus reporting
- Window title (OSC 0)
- Attribute reset

---

### SignalHandler

**File:** `Sources/Chai/Core/Program.swift` (private)

`SignalHandler` uses `DispatchSource.makeSignalSource` to handle three POSIX signals:

| Signal | Action |
|--------|--------|
| `SIGWINCH` | Sends `WindowResizeSignalMsg` (sentinel). `ProgramRunner` resolves the actual size via `terminal.size()` and sends `WindowSizeMsg`. |
| `SIGINT` | Sends `QuitMsg` — equivalent to the user pressing Ctrl+C in a shell. |
| `SIGTERM` | Sends `QuitMsg` — allows graceful shutdown when the process is killed. |

Before installing the dispatch sources, the default signal disposition is suppressed with `signal(SIG, SIG_IGN)`. On `stop()`, sources are cancelled and dispositions are restored to `SIG_DFL`.

The two-step design for `SIGWINCH` (sentinel → runner queries size) is necessary because `SignalHandler` does not hold a reference to `Terminal`. The runner does, and it handles `WindowResizeSignalMsg` in `handleRendererMessage` before delivering the message to the model.

---

## Latte — Layout & Styling Library

**Path:** `Sources/Latte/`

Latte is a standalone library (no dependency on Chai) that provides layout primitives and text styling utilities for building terminal UIs. It operates on plain strings (with ANSI escape code awareness) and produces styled string output.

### Modules

| Module | Files | Purpose |
|--------|-------|---------|
| **Borders** | `Border.swift`, `BorderRenderer.swift` | Render bordered boxes around text content. Supports rounded, normal, double, thick, ASCII, and hidden styles. Selective side rendering (top/bottom/left/right). |
| **Layout** | `Alignment.swift`, `Margin.swift`, `Padding.swift`, `Size.swift`, `Wrap.swift`, `Inline.swift` | Core layout functions — horizontal/vertical alignment (left, center, right, fractional), padding and margin with custom fill characters, width/height enforcement and clamping, word-wrapping with ANSI-aware line breaking, inline extraction. |
| **Composition** | `Join.swift`, `Place.swift` | Compose multiple blocks — horizontal and vertical joins with alignment control, absolute placement within a canvas. |
| **Measurement** | `DisplayWidth.swift` | Unicode-aware visible width calculation. Handles CJK double-width characters, ANSI escape code exclusion, and ANSI-aware string truncation. |
| **Utilities** | `TabExpansion.swift`, `StringLines.swift` | Tab-to-spaces expansion with configurable tab width, line splitting utilities. |
| **Extensions** | `String+Layout.swift` | Chainable `String` extensions (`.padded()`, `.bordered()`, `.aligned()`, `.wrapped()`, `.margined()`, `.placed()`, `.clamped()`, `.enforced()`, `.truncated()`, `.inlined()`, `.tabsExpanded()`). |

### Design Notes

- **ANSI-aware:** All width calculations and truncation functions correctly skip ANSI escape sequences (CSI, OSC, SS2, SS3) so that styling codes do not affect layout math.
- **Pure functions:** Layout functions are stateless — they take a string and configuration, and return a new string. No side effects.
- **Chainable API:** `String+Layout.swift` provides method-chaining extensions that mirror the free functions, enabling `"hello".padded(1).bordered().margined(1)`.

---

## Spices — Component Library

**Path:** `Sources/Spices/`

Spices provides pre-built, reusable interactive components built on top of Chai's Elm Architecture. Each component is a `struct` conforming to Chai's `Model` protocol (or designed to be embedded within a parent model).

### Components

| Component | File | Description |
|-----------|------|-------------|
| **TextInput** | `TextInput/TextInput.swift` | Single-line text input with cursor navigation, character limits, and focus/blur support. |
| **TextArea** | `TextArea/TextArea.swift` | Multi-line text editing. |
| **List** | `List/List.swift`, `List/FilterDelegate.swift` | Scrollable, selectable list with optional filtering/search. |
| **Table** | `Table/Table.swift` | Tabular data display with column formatting. |
| **Viewport** | `Viewport/Viewport.swift` | Scrollable content viewport with percentage-based scroll tracking. |
| **Spinner** | `Spinner/Spinner.swift` | Animated loading spinner. |
| **Progress** | `Progress/Progress.swift` | Progress bar with percentage display. |
| **Timer** | `Timer/Timer.swift` | Countdown/elapsed timer with formatted display. |
| **Stopwatch** | `Stopwatch/Stopwatch.swift` | Elapsed time tracking. |
| **Paginator** | `Paginator/Paginator.swift` | Page navigation for paginated content. |
| **FilePicker** | `FilePicker/FilePicker.swift` | File system browser. |
| **Help** | `Help/Help.swift` | Keyboard shortcut help display. |
| **KeyBinding** | `KeyBinding/KeyBinding.swift` | Declarative key binding matching with pattern support. |
| **Cursor** | `Cursor/Cursor.swift` | Cursor position and shape management. |
| **Style** | `Style/Style.swift`, `Style/Color.swift` | ANSI text styling (bold, foreground/background color, hex colors, 256-color, true color). |

### Internal Utilities

| File | Purpose |
|------|---------|
| `Internal/IDGenerator.swift` | Unique ID generation for component instances. |

### Design Notes

- **Depends on Chai only.** Spices imports `Chai` for the `Model`, `Message`, `Command`, and `KeyMsg` types. It does not depend on Latte.
- **Composable.** Components are value types that can be embedded as fields within a parent model's `struct` and updated by delegating messages.

---

## Data Flow

```
STDIN bytes
    │
    ▼
InputReader (background Thread)
    │  select(2) on stdin + cancel pipe
    │  read(2) up to 256 bytes
    │
    ▼
InputParser.parse(buffer:canHaveMoreData:)
    │  pure [UInt8] → [any Message]
    │
    ▼
AsyncStream<any Message>.Continuation.yield
    │
    ▼
ProgramRunner.messageStream (AsyncStream)
    │
    ├─► handleRendererMessage(msg)   [resize, repaint, println]
    │       │
    │       └─► Renderer (actor)
    │               └─► Terminal.write(ansiString)
    │
    ├─► model.update(msg) → Command?
    │
    ├─► renderer.write(model.view())   [ViewOutput: content + terminal state]
    │
    └─► execute(cmd)
            │
            ├─ .perform  → Task { msg = await work(); send(msg) }
            ├─ .batch    → execute each concurrently
            ├─ .sequence → execute each, await message, then next
            ├─ .quit     → send(QuitMsg())
            └─ .setWindowTitle → renderer.setWindowTitle(title)
```

---

## Concurrency Model

Chai uses three concurrency contexts:

| Context | Mechanism | What runs there |
|---------|-----------|-----------------|
| **Event loop** | `async` function on cooperative pool | `ProgramRunner.run()`, model mutations, command dispatch |
| **Render loop** | Actor-isolated `Task` | `Renderer.flush()` every 1/fps seconds |
| **Input reader** | Dedicated `Thread` | Blocking `select(2)` + `read(2)` on stdin |

**Why not run the input reader as a `Task`?**

Swift's cooperative thread pool has a fixed number of threads (typically equal to the number of CPU cores). A `Task` that blocks on `read(2)` would permanently occupy one of those threads, potentially deadlocking the pool under load. A dedicated `Thread` blocks independently of the pool.

**`AsyncStream` as the message bus:**

All event sources write to a single `AsyncStream<any Message>` via its `Continuation`. The event loop iterates this stream with `for await`. This gives a single, ordered, backpressure-aware queue with no explicit locking.

**`@unchecked Sendable` on `ProgramRunner`:**

`ProgramRunner` holds mutable state (`model`, `renderer`, etc.) but is marked `@unchecked Sendable`. This is safe because:
- `model` is only mutated inside the `async` event loop (single-task access).
- `renderer` is an actor (self-serialising).
- `terminal` is `@unchecked Sendable` (its `write` method is thread-safe via `write(2)`).
- `messageContinuation` is safe to call from any thread (documented by `AsyncStream`).

---

## Input Pipeline

```
Raw bytes from stdin
        │
        │  (background Thread, select + read)
        ▼
┌───────────────────┐
│   InputReader     │  Manages the Thread lifecycle and cancellation pipe.
│                   │  Accumulates leftover bytes across reads.
└────────┬──────────┘
         │ [UInt8] buffer
         ▼
┌───────────────────┐
│   InputParser     │  Pure static functions. No I/O.
│                   │
│  parseOne():      │
│   CSI sequences   │  ESC [ params finalByte  →  csiTable lookup
│   SS3 sequences   │  ESC O byte              →  ss3Table lookup
│   Alt modifier    │  ESC + next key          →  KeyMsg(alt: true)
│   Named controls  │  0x08/0x09/0x0D/0x7F     →  backspace/tab/enter
│   Generic ctrl    │  0x01–0x1A               →  ctrl("a")–ctrl("z")
│   Printable UTF-8 │  consecutive runes        →  KeyMsg(.runes, [...])
└────────┬──────────┘
         │ [any Message]
         ▼
  AsyncStream.yield  →  event loop
```

**Batching of printable runes:**

`parsePrintable` consumes as many consecutive printable bytes as possible in one call, producing a single `KeyMsg` with multiple runes. This matches Bubble Tea's behaviour and is important for paste events, where many characters arrive in one `read(2)` call.

---

## Rendering Pipeline

```
model.view() → ViewOutput
        │
        ▼
renderer.write(viewOutput)    stores in pendingViewOutput
        │
        │  (every 1/fps seconds, on actor executor)
        ▼
renderer.flush()
        │
        ├─ diff terminal state (altScreen, windowTitle, cursorHidden)
        │     altScreen changed?     →  enter/exit + clear render cache
        │     windowTitle changed?   →  OSC 0 sequence
        │     cursorHidden changed?  →  show/hide cursor
        │
        ├─ content == lastContent?   →  skip content flush
        │
        ├─ split content into lines
        ├─ clamp to termHeight
        │
        ├─ move cursor to top of previous render
        ├─ flush queuedLines (println, normal screen only)
        │
        ├─ for each line:
        │     same as lastLines[i]?  →  skip (emit \n only)
        │     changed?               →  write line + ESC[K
        │
        ├─ prevCount > newCount?     →  ESC[J (erase below)
        │
        └─ park cursor
                │
                ▼
        wrap with synchronized output markers (mode 2026)
        terminal.write(assembled ANSI string)
```

The content output is wrapped with synchronized update markers (`ANSI.beginSyncUpdate` / `ANSI.endSyncUpdate`, mode 2026) to prevent partial-frame tearing on supporting terminals. Terminals that do not support mode 2026 silently ignore these sequences. Terminal state transitions (alt screen, window title, cursor visibility) are written outside the sync markers since they are brief, non-visual operations that do not cause tearing.

The renderer diffs **both terminal state and content** between frames. Terminal state fields in `ViewOutput` that are `nil` are ignored (current state is preserved). Non-nil fields are compared against the last applied state and transitions are emitted only when values change.

The key content optimisation is **line-level diffing**: only lines that changed since the last frame are rewritten. This minimises the number of bytes sent to the terminal, which matters for slow connections (SSH) and large UIs.

The entire content frame is assembled into a single `String` before calling `terminal.write()`. This reduces the number of `write(2)` syscalls to one per frame.

---

## Command Execution

Commands are executed by `ProgramRunner.execute(_:)`:

**`.perform`** — the most common case:
```swift
case .perform(let work):
    Task { [weak self] in
        let msg = await work()
        self?.send(msg)
    }
```
Each `.perform` spawns an independent `Task`. The result is sent back into the message stream when the async work completes.

**`.batch`** — concurrent execution:
```swift
case .batch(let cmds):
    for cmd in cmds { execute(cmd) }
```
Each command in the batch is executed independently. Messages arrive in unspecified order.

**`.sequence`** — ordered execution:
```swift
case .sequence(let cmds):
    Task {
        for cmd in cmds {
            await withCheckedContinuation { cont in
                // execute cmd, resume cont when its message is sent
            }
        }
    }
```
A single `Task` iterates the commands. For `.perform` commands, it waits for the async work to complete and the message to be sent before moving to the next command. Non-`.perform` commands (e.g. `.quit`, `.setWindowTitle`) are executed synchronously and the continuation resumes immediately.

**`.quit`** — sends `QuitMsg()` into the stream, which breaks the event loop.

**`.setWindowTitle`** — calls `renderer.setWindowTitle` from a new `Task` (actor call must be `await`ed).

---

## Signal Handling

```
SIGWINCH ──► DispatchSource ──► send(WindowResizeSignalMsg)
                                        │
                                        ▼
                              handleRendererMessage:
                                terminal.size()  (ioctl TIOCGWINSZ)
                                renderer.setSize(w, h)
                                send(WindowSizeMsg(w, h))
                                        │
                                        ▼
                              model.update(WindowSizeMsg)

SIGINT  ──► DispatchSource ──► send(QuitMsg)
SIGTERM ──► DispatchSource ──► send(QuitMsg)
```

The two-step `SIGWINCH` flow exists because `SignalHandler` does not hold a reference to `Terminal`. The sentinel `WindowResizeSignalMsg` is an internal type; the model never sees it. The model only ever receives the resolved `WindowSizeMsg` with the actual dimensions.

---

## Lifecycle

```
Program.run()
    │
    ├─ terminal.enableRawMode()
    ├─ renderer.enterAltScreen()     (if .withAltScreen)
    ├─ renderer.setWindowTitle()     (if .withWindowTitle)
    ├─ renderer.start()              (begin flush loop)
    ├─ terminal.size() → send(WindowSizeMsg)
    ├─ signalHandler.start()
    ├─ inputReader.start()
    ├─ model.initialize() → execute(cmd)
    ├─ renderer.write(model.view()) + renderer.flush()
    │
    ├─ [event loop] ──────────────────────────────────────────┐
    │       for await msg in messageStream                     │
    │           handleRendererMessage(msg)                     │
    │           model.update(msg) → cmd                        │
    │           renderer.write(model.view())  → ViewOutput     │
    │           execute(cmd)  or  break on .quit / QuitMsg     │
    └──────────────────────────────────────────────────────────┘
    │
    ├─ inputTask.cancel()
    ├─ inputReader.stop()
    ├─ signalHandler.stop()
    ├─ renderer.stop()               (final flush + erase last line)
    ├─ renderer.exitAltScreen()      (if altScreenActive)
    ├─ terminal.write(showCursor)
    └─ terminal.disableRawMode()     (via defer)
```

The `defer { terminal.disableRawMode() }` at the top of `run()` ensures the terminal is always restored, even if an error is thrown.

---

## Testing Strategy

Tests use Swift Testing (`@Test`, `#expect`) across three test targets.

### InputParserTests (35 tests)

`InputParser` is a pure function — no mocks needed. Tests cover:

- All named keys (enter, tab, backspace, escape, space, delete)
- Arrow keys (plain, Shift, Ctrl, Ctrl+Shift)
- Home, End, Page Up/Down, Insert
- Function keys F1–F20 (all encoding variants)
- SS3 sequences
- Ctrl+letter (A–Z), including the named-before-generic ordering
- Alt modifier (Alt+letter, Alt+arrow)
- Printable ASCII and multi-byte UTF-8
- Rune batching (multiple printable characters in one read)
- Incomplete sequence handling (`canHaveMoreData`)
- Unknown/unrecognised sequences

### RendererTests (31 tests)

`Renderer` is tested via `MockTerminalOutput`, a `TerminalOutput` conformance that appends written strings to an array. Tests cover:

- Initial render (cursor reset, line writing)
- Line-level diffing (unchanged lines are skipped)
- Alt screen enter/exit (direct and via `ViewOutput`)
- Cursor hide/show (direct and via `ViewOutput`)
- Window title (direct and via `ViewOutput`)
- `println` (queued lines appear above live view)
- `repaint` (forces full redraw)
- Terminal size clamping (lines beyond `termHeight` are dropped)
- Declarative `ViewOutput` terminal state transitions
- Nil terminal state preserves current state (no transition)
- Combined terminal state changes in a single `ViewOutput`
- String literal `ViewOutput` passthrough (no terminal state changes)
- Alt screen transition clears render cache
- Synchronized output markers (present on content flush, absent when unchanged)
- ANSI-aware width truncation (escape codes not counted, plain text clipped)

### DisplayWidthTests (24 tests)

**File:** `Tests/ChaiTests/RendererTests.swift`

Tests cover:

- Single character width calculation (ASCII → 1, CJK → 2, Hangul → 2, fullwidth → 2, control → 0)
- Visible width measurement with ANSI sequences (CSI, OSC with BEL and ST terminators)
- Visible width ignores SS3 (ESC O), SS2 (ESC N), and simple two-byte escape sequences
- ANSI-aware truncation preserving escape sequences and handling wide character boundaries
- Truncation of SS3/SS2 sequences (zero visual width, passed through)
- OSC with ST terminator (ESC \\) correctly skipped in both measurement and truncation

### ViewOutputTests (6 tests)

Tests cover:

- String literal creation (content set, terminal state nil)
- String interpolation creation
- Explicit init with all fields
- Default `nil` values
- `Equatable` conformance

### CommandTests (10 tests)

Tests cover:

- `.perform` — async work executes and message is delivered
- `.batch` — all commands run, all messages arrive
- `.sequence` — messages arrive in order
- `.quit` — `QuitMsg` is sent
- `.tick` — fires after the specified duration
- `.every` — fires at the next wall-clock boundary
- `.println` — produces a `PrintLineMsg`
- `.setWindowTitle` — produces the correct ANSI sequence
- Integration: a `Model` that uses commands to update its state

### LatteTests (Tests/LatteTests/)

Tests cover all layout and styling modules:

| Test file | Coverage |
|-----------|----------|
| `DisplayWidthTests.swift` | Character width calculation, ANSI-aware visible width, truncation |
| `BorderTests.swift` | All border styles, selective sides, ANSI preservation, equatable |
| `AlignmentTests.swift` | Left/center/right/fractional alignment, ANSI-aware padding, multi-line |
| `PaddingTests.swift` | All-sides padding, shorthand constructors, custom fill characters, ANSI preservation |
| `SizeTests.swift` | Width/height measurement, enforce/clamp dimensions, ANSI awareness |
| `WrapTests.swift` | Word wrapping at spaces/hyphens/commas, wide characters, ANSI carry-over |
| `InlineTests.swift` | First-line extraction, ANSI preservation, composition with other functions |
| `JoinTests.swift` | Horizontal/vertical joins, alignment options, ANSI preservation |
| `PlaceTests.swift` | Canvas placement, horizontal/vertical alignment, bordered content |
| `StringExtensionTests.swift` | Chainable string extensions, composition chains |
| `TabExpansionTests.swift` | Tab-stop alignment, custom widths, ANSI interaction |

### SpicesTests (Tests/SpicesTests/)

| Test file | Coverage |
|-----------|----------|
| `SpicesTests.swift` | Component initialization, state management, view rendering, key binding matching, style rendering |

---

## Package Layout

```
chai/
├── Package.swift                        # swift-tools-version: 6.1.2
│                                        # macOS 14+, StrictConcurrency enabled
│
├── Sources/
│   ├── Chai/                            # Core TUI framework
│   │   ├── Chai.swift                   # Module documentation entry point
│   │   ├── Core/
│   │   │   ├── Model.swift              # Model protocol
│   │   │   ├── Message.swift            # Message protocol + built-in messages
│   │   │   ├── Command.swift            # Command enum + convenience factories
│   │   │   └── Program.swift            # Program<M>, ProgramRunner, SignalHandler
│   │   ├── Terminal/
│   │   │   ├── ANSICodes.swift          # ANSI/VT100 escape sequence constants
│   │   │   ├── Terminal.swift           # TerminalOutput protocol + Terminal class
│   │   │   ├── InputReader.swift        # Async stdin reader (background Thread)
│   │   │   └── InputParser.swift        # Pure byte-sequence parser → KeyMsg
│   │   └── Renderer/
│   │       └── Renderer.swift           # Actor-based framerate diff renderer
│   │
│   ├── Latte/                           # Layout & styling library (standalone)
│   │   ├── Latte.swift                  # Module entry point
│   │   ├── Borders/
│   │   │   ├── Border.swift             # Border styles and configuration
│   │   │   └── BorderRenderer.swift     # Border rendering logic
│   │   ├── Layout/
│   │   │   ├── Alignment.swift          # Horizontal/vertical/fractional alignment
│   │   │   ├── Margin.swift             # Margin (outer spacing)
│   │   │   ├── Padding.swift            # Padding (inner spacing)
│   │   │   ├── Size.swift               # Width/height enforcement and clamping
│   │   │   ├── Wrap.swift               # ANSI-aware word wrapping
│   │   │   └── Inline.swift             # First-line extraction
│   │   ├── Composition/
│   │   │   ├── Join.swift               # Horizontal/vertical block joining
│   │   │   └── Place.swift              # Absolute canvas placement
│   │   ├── Measurement/
│   │   │   └── DisplayWidth.swift       # Unicode-aware visible width
│   │   ├── Utilities/
│   │   │   ├── TabExpansion.swift        # Tab-to-spaces expansion
│   │   │   └── StringLines.swift        # Line splitting utilities
│   │   └── Extensions/
│   │       └── String+Layout.swift      # Chainable String extensions
│   │
│   └── Spices/                          # Component library (depends on Chai)
│       ├── Spices.swift                 # Module entry point
│       ├── TextInput/TextInput.swift    # Single-line text input
│       ├── TextArea/TextArea.swift      # Multi-line text editing
│       ├── List/
│       │   ├── List.swift               # Selectable list with filtering
│       │   └── FilterDelegate.swift     # Filter behavior delegate
│       ├── Table/Table.swift            # Tabular data display
│       ├── Viewport/Viewport.swift      # Scrollable content viewport
│       ├── Spinner/Spinner.swift        # Animated loading spinner
│       ├── Progress/Progress.swift      # Progress bar
│       ├── Timer/Timer.swift            # Countdown/elapsed timer
│       ├── Stopwatch/Stopwatch.swift    # Elapsed time tracking
│       ├── Paginator/Paginator.swift    # Page navigation
│       ├── FilePicker/FilePicker.swift  # File system browser
│       ├── Help/Help.swift              # Keyboard shortcut help
│       ├── KeyBinding/KeyBinding.swift  # Declarative key binding matching
│       ├── Cursor/Cursor.swift          # Cursor management
│       ├── Style/
│       │   ├── Style.swift              # ANSI text styling
│       │   └── Color.swift              # Color definitions (hex, 256, true color)
│       └── Internal/
│           └── IDGenerator.swift        # Unique ID generation
│
├── Tests/
│   ├── ChaiTests/
│   │   ├── InputParserTests.swift       # 35 tests
│   │   ├── RendererTests.swift          # 61 tests (Renderer + DisplayWidth + ViewOutput)
│   │   └── CommandTests.swift           # 10 tests
│   ├── LatteTests/                      # 11 test files covering all layout modules
│   │   ├── DisplayWidthTests.swift
│   │   ├── BorderTests.swift
│   │   ├── AlignmentTests.swift
│   │   ├── PaddingTests.swift
│   │   ├── SizeTests.swift
│   │   ├── WrapTests.swift
│   │   ├── InlineTests.swift
│   │   ├── JoinTests.swift
│   │   ├── PlaceTests.swift
│   │   ├── StringExtensionTests.swift
│   │   └── TabExpansionTests.swift
│   └── SpicesTests/
│       └── SpicesTests.swift            # Component tests
│
└── Examples/
    └── GroceryList/
        └── Sources/
            └── main.swift               # Grocery list example app
```

**Package targets:**

| Target | Type | Dependencies | Description |
|--------|------|-------------|-------------|
| `Chai` | library | — | Core TUI framework |
| `Latte` | library | — | Layout & styling primitives |
| `Spices` | library | Chai | Pre-built interactive components |
| `ChaiTests` | test | Chai | Core framework tests |
| `LatteTests` | test | Latte | Layout & styling tests |
| `SpicesTests` | test | Spices | Component tests |
| `GroceryList` | executable | Chai | Example app |

---

## Design Decisions & Trade-offs

### Why a background `Thread` for input, not `Task`?

Swift's cooperative thread pool must not be blocked. `read(2)` on a TTY is a blocking call. Using a dedicated `Thread` keeps the cooperative pool free for `async`/`await` work. The `select(2)` + cancellation pipe pattern gives clean, race-free shutdown.

### Why an `actor` for `Renderer`, not a lock?

Actors provide data-race safety enforced by the compiler (with `StrictConcurrency`). They also compose naturally with `async`/`await` — callers simply `await` actor methods. A manual lock would require `@unchecked Sendable` and careful discipline.

### Why `any Message` (existential) instead of a generic `Message` type parameter?

Using an existential allows the message stream (`AsyncStream<any Message>`) to carry heterogeneous message types without requiring the user to define a single app-wide message enum. The trade-off is a small runtime cost for dynamic dispatch, which is negligible for a UI event loop.

### Why value semantics for `Model`?

Value semantics make state mutations explicit (`mutating func`) and prevent accidental aliasing bugs. The compiler enforces that the model is not shared across concurrency boundaries. The single authoritative copy lives in `ProgramRunner` and is mutated only on the event loop.

### Why line-level diffing in the renderer?

Full-screen redraws on every frame would send a large number of bytes to the terminal, causing visible flicker on slow connections (SSH) and wasting CPU on ANSI parsing in the terminal emulator. Line-level diffing typically reduces output by 90%+ for UIs that change only a few lines per frame.

### Why assemble the entire frame into one `String` before writing?

Each `write(2)` syscall has overhead. Assembling the frame into a single string and writing it in one call minimises syscall count and ensures the terminal receives the frame atomically (no partial-frame flicker between syscalls).

### Why `DispatchSource` for signal handling, not `sigaction`?

`DispatchSource.makeSignalSource` integrates cleanly with Swift's concurrency model and GCD. It delivers signal events on a dispatch queue, where they can safely call `messageContinuation.yield`. Using `sigaction` with a raw C signal handler would require async-signal-safe code, which is extremely restrictive and incompatible with Swift's runtime.

### Why a sentinel message for `SIGWINCH`?

`SignalHandler` does not hold a reference to `Terminal` (separation of concerns). Rather than coupling them, `SignalHandler` sends a `WindowResizeSignalMsg` sentinel. `ProgramRunner` intercepts it in `handleRendererMessage`, queries the terminal size itself, and sends the resolved `WindowSizeMsg` to the model. The model never sees the sentinel.
