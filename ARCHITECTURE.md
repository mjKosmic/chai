# Chai Architecture

Chai is a Swift-native terminal UI (TUI) framework inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea). It implements the **Elm Architecture** (Model-Update-View) using modern Swift concurrency — `async`/`await`, actors, `AsyncStream`, and structured `Task`s — with zero runtime dependencies outside the Swift standard library.

The repository is a monorepo containing three libraries:

| Library | Purpose | Dependencies |
|---------|---------|--------------|
| **Chai** | Core TUI framework (Elm Architecture runtime, input handling, rendering, the layout engine's value types and SPI) | None |
| **Latte** | Layout and styling library (borders, padding, alignment, wrapping, sizing, `Style`, `Color`, `ColorProfile`) plus the declarative containers (`HStack`/`VStack`, `FrameView`) | Chai |
| **Spices** | Pre-built interactive components (text input, lists, tables, spinners, timers, etc.) | Chai, Latte |

Latte's dependency on Chai is the phase-1 migration: `HStack`/`VStack` and `FrameView` conform to Chai's ``View`` protocol and are laid out by its engine. Latte's string-level layout functions (`align`, `join`, `border`, ...) remain standalone and operate on plain `String`/`StyledText` values. The package also declares `swift-docc-plugin` (build-time only) for DocC documentation generation; no runtime dependency is introduced.

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
6. [The Layout Engine](#the-layout-engine)
   - [The measure/render flow](#the-measurerender-flow)
   - [Who the engine SPI is for](#who-the-engine-spi-is-for)
   - [Query and allocation semantics](#query-and-allocation-semantics)
   - [Minimum queries (`AvailableSize.zero`)](#minimum-queries-availablesizezero)
   - [Why there is no `.infinity`](#why-there-is-no-infinity)
   - [The parity discipline](#the-parity-discipline)
   - [`frame()` — one modifier](#frame--one-modifier)
7. [Spices — Component Library](#spices--component-library)
8. [Data Flow](#data-flow)
9. [Concurrency Model](#concurrency-model)
10. [Input Pipeline](#input-pipeline)
11. [Rendering Pipeline](#rendering-pipeline)
12. [Command Execution](#command-execution)
13. [Signal Handling](#signal-handling)
14. [Lifecycle](#lifecycle)
15. [Testing Strategy](#testing-strategy)
16. [Package Layout](#package-layout)
17. [Design Decisions & Trade-offs](#design-decisions--trade-offs)

---

## Design Philosophy

| Principle | How it is applied |
|-----------|-------------------|
| **Value semantics for state** | `Model` is a `Sendable` value type (`struct`). `update` is `mutating`. No shared mutable state in user code. |
| **Unidirectional data flow** | Messages flow in → model updates → view renders. No callbacks, no delegates. |
| **Zero runtime dependencies** | Library code uses only Swift stdlib, Foundation, and POSIX APIs (`termios`, `ioctl`, `select`). The package declares `swift-docc-plugin` as build-time tooling only. |
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
│  └──────────────┘                │  model.body         │  │
│                                  │  (view tree)        │  │
│                                  │       │              │  │
│  ┌──────────────┐    commands    │       ▼              │  │
│  │   Command    │ ◄──────────────│  execute(cmd)        │  │
│  │  execution   │                │                      │  │
│  │  (Tasks)     │ ─── msgs ─────►│                      │  │
│  └──────────────┘                └──────────┬───────────┘  │
│                                             │  any View     │
│                                             ▼              │
│                                  ┌──────────────────────┐  │
│                                  │   Renderer (actor)   │  │
│                                  │  layout engine flush │  │
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
            body ──► view tree ──► Renderer (layout engine)
```

### The three model methods

```swift
public protocol Model: View, Sendable {
    func initialize() -> Command?
    mutating func update(_ msg: any Message) -> Command?
    var cursor: Cursor? { get }   // default nil
    // `body` (and the layout engine SPI) come from `View`
}
```

- **`initialize()`** — called once at startup. Returns an optional `Command` for initial I/O (e.g. loading data, starting a timer).
- **`update(_ msg:)`** — called for every incoming `Message`. Mutates state and optionally returns a `Command` for further async work.
- **`body`** — the ``View`` tree rendered after every `update`. ``Model`` inherits from ``View``, so a model *is* a view: `body` may be any `View` — a ``ViewOutput`` leaf, a stack, a `frame()`, or a ``@ViewBuilder`` composition — and the renderer accepts it directly. `ViewOutput` still conforms to `ExpressibleByStringInterpolation`, so simple models can return a string literal from `body`.

The model is a **value type**. `ProgramRunner` holds the single authoritative copy and mutates it in-place on the event loop. There is no diffing of the model itself — `body` is always read after every message.

---

## Component Reference

### Model

**File:** `Sources/Chai/Core/Model.swift`

The `Model` protocol is the only type users must implement. It carries four constraints:

- `Sendable` — the model must be safe to pass across concurrency boundaries (required because `Program` is generic over `M: Model` and `Program` itself is `Sendable`).
- `mutating func update` — enforces value semantics; the compiler prevents accidental shared-state bugs.
- Inherits `View` — a model *is* a view and supplies `var body: some View`, so no separate `view()` method exists. `body` may be any `View` (see [The Elm Architecture in Chai](#the-elm-architecture-in-chai)).
- `var cursor: Cursor?` — the terminal cursor to display, with a default of `nil` (hidden in alt-screen mode, unchanged in normal mode). Previously a field on `ViewOutput`, cursor state became a model property in the phase-1 terminal-state split.

`body` typically composes child views with `@ViewBuilder` and returns them as an opaque `some View`. Terminal state is no longer declared per-frame inside the view tree: alt screen is a ``Program`` option, window title is a ``Command``, and the cursor is the model's ``cursor`` property.

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
| `.withLogger(logger)` | Attaches a ``ChaiLogger`` for internal diagnostics (e.g. ``FileLogger``; stdout is owned by the terminal). |

**Event loop (simplified):**

```swift
eventLoop: for await msg in messageStream {
    await handleRendererMessage(msg)   // resize, repaint, println
    let cmd = model.update(msg)        // update model
    await renderer.write(model.body)   // queue view tree
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
| `pendingView` | The `View` tree queued for the next flush (stored as an existential, laid out lazily) |
| `pendingCursor` | The `Cursor` queued for the next flush (set separately from content) |
| `lastBuffer` | The `CellBuffer` from the last rendered frame (for cell-level diffing) |
| `altScreenActive` | Whether the alt screen buffer is active |
| `termWidth` / `termHeight` | Current terminal dimensions |
| `queuedLines` | Lines waiting to be printed above the live view |
| `cursorHidden` | Whether the cursor is currently hidden |
| `lastCursor` | The cursor from the last frame (for diffing) |
| `cursorParkedRow` | Row where the terminal cursor is parked (for movement deltas) |
| `lastWindowTitle` | The last applied window title (for diffing) |
| `flushTask` | The background `Task` driving the render loop |

**Render loop:**

`start()` spawns a `Task` that sleeps for `1000/fps` milliseconds, then calls `flush()`, in a loop. Default is 60 FPS (≈16.7 ms per frame).

**`flush()` algorithm:**

`flush()` builds the frame through the layout engine; see [The Layout Engine](#the-layout-engine) for the measure/render flow in detail.

1. Handle cursor visibility: show the cursor when `pendingCursor` is set (and it was hidden), hide it in alt-screen mode when no cursor is set.
2. Query the terminal size: `view._measure(in: AvailableSize(width: w, height: altScreenActive ? h : nil))` — inline mode queries width only (the buffer is content-sized), alt-screen mode queries the fixed terminal size. The answer is a **report**: it sizes the buffer (and, inline, the root allocation's height); it never binds a child's paint.
3. Decide the buffer height from the reported size:
   - Empty content (`height == 0`) → a single-row buffer (keeps cursor-position tracking; `Cell.empty` is a space cell so the extra row renders invisibly).
   - Alt screen → fixed `termHeight`.
   - Inline → clamped to `termHeight` (suffix lines win, reproducing the old `content.suffix(lines:)` behavior).
4. Allocate the buffer with the renderer's wrap-vs-truncate policy: **truncate** inline (the height is content-derived; wrapping would steal rows), **wrap** in alt screen. The mode decision stays renderer-level; the leaf SPI carries no mode flags.
5. Inline suffix clamp: when the measured height exceeds `termHeight`, embed at a negative row origin (`bufferHeight - measured.height`) so only the bottom `bufferHeight` rows land in the buffer — byte-identical to the eager suffix. Alt screen renders from the top; out-of-bounds rows are dropped by the buffer's bounds guards.
6. `newBuffer.embed(view, at: ViewRect(origin: origin, size: (w, rootHeight)))` — ONE allocation walk places every view into the buffer. `rootHeight` is `bufferHeight` in alt-screen mode (the root may fill the screen) and `measured.height` inline; each container decides its children's rects, and the kernel clip contains every view to its rect.
7. Diff `newBuffer` against `lastBuffer` (per-cell changes + `eraseBelow`).
8. Move the cursor back to the top of the previous render, flush queued `println` lines (normal screen only), then paint each changed row (`row` + `ESC[K`), emitting `\n` for unchanged rows. On the first render (empty `lastBuffer`) force a full repaint so blank padding rows are not skipped and stale content cannot ghost through.
9. If the previous frame had more rows than the new frame, emit `ESC[J` (erase screen below).
10. Park the cursor, wrap the assembled output in synchronized-update markers (mode 2026), and write it in one `terminal.write()` call.

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

Latte provides layout primitives, ANSI text styling, and (since phase 1) the declarative containers for building terminal UIs. The package target depends on **Chai** because `HStack`/`VStack`/`FrameView` conform to Chai's ``View`` protocol and participate in its layout engine; the string-level layout functions remain pure and operate on plain strings (with ANSI escape code awareness) and ``StyledText`` values.

### Modules

| Module | Files | Purpose |
|--------|-------|---------|
| **Style** | `Style.swift`, `Color.swift`, `ColorProfile.swift`, `ColorPalette.swift`, `ColorUtilities.swift` | ANSI text styling — composable `Style` values (bold, italic, colors), `Color` (ANSI 16 / 256 / true color with hex support), `ColorProfile` (terminal capability detection and color downsampling). |
| **Borders** | `Border.swift`, `BorderRenderer.swift` | Render bordered boxes around text content. Supports rounded, normal, double, thick, ASCII, and hidden styles. Selective side rendering (top/bottom/left/right). `Style?` parameters (`borderStyle`, `topStyle`, `bottomStyle`, `leftStyle`, `rightStyle`) style border characters natively. Per-side styles override the shared `borderStyle`; corners inherit the style of their horizontal edge. Content inside the border is never styled. |
| **Layout** | `Alignment.swift`, `Margin.swift`, `Padding.swift`, `Size.swift`, `Wrap.swift`, `Inline.swift`, `Stacks.swift`, `Frame.swift`, `PaddingView.swift`, `BorderView.swift`, `CompositionWrappers.swift` | Core layout functions — horizontal/vertical alignment (left, center, right, fractional), padding and margin with custom fill characters, width/height enforcement and clamping, word-wrapping with ANSI-aware line breaking, inline extraction — plus the declarative containers and wrappers: `VStack`/`HStack` (`Stacks.swift`), `FrameView` with the `frame(...)` modifier (`Frame.swift`), the `PaddingView`/`BorderView` modifiers, and `.beside`/`.above` stack sugar (`CompositionWrappers.swift`). |
| **Composition** | `Join.swift`, `Compositor.swift` | Compose multiple blocks — horizontal and vertical joins with alignment control (`Join.swift`), and z-ordered canvas placement of positioned `Layer` blocks (`Compositor.swift`, the successor to the old `Place.swift` module). |
| **Measurement** | `DisplayWidth.swift` | Unicode-aware visible width calculation. Handles CJK double-width characters, ANSI escape code exclusion, and ANSI-aware string truncation. |
| **Static** | `ListRenderer.swift`, `TreeRenderer.swift` | Static list and tree renderers for non-interactive output. |
| **Utilities** | `TabExpansion.swift`, `StringLines.swift` | Tab-to-spaces expansion with configurable tab width, line splitting utilities. |
| **Extensions** | `String+Layout.swift`, `StyledText+Layout.swift`, `ViewOutput+Layout.swift` | Chainable extensions: `String` (`.padded()`, `.bordered()`, `.aligned()`, `.wrapped()`, `.margined()`, `.placed()`, `.clamped()`, `.enforced()`, `.truncated()`, `.inlined()`, `.tabsExpanded()`), `StyledText` layout, and the ``ViewOutput`` raster helpers (`.clampedWidth()`, `.clampedHeight()`). |

### Design Notes

- **ANSI-aware:** All width calculations and truncation functions correctly skip ANSI escape sequences (CSI, OSC, SS2, SS3) so that styling codes do not affect layout math.
- **Pure functions:** Layout functions are stateless — they take a string and configuration, and return a new string. No side effects.
- **Chainable API:** `String+Layout.swift` provides method-chaining extensions that mirror the free functions, enabling `"hello".padded(1).bordered().margined(1)`.
- **Styling via `Style?`:** Border rendering accepts optional ``Style`` parameters for styling border characters. Because `Style` lives in Latte itself, no extra imports or closure adapters are needed at the call site.
- **One API generation:** the declarative containers (`HStack`/`VStack`/`FrameView`) and the tree modifiers (`.padded`, `.bordered`, `.frame`) render through the layout engine. The phase-1 eager ``ViewOutput`` modifier family retired in phase-4 P4b; only the raster clamping helpers remain on ``ViewOutput`` (see [The Layout Engine](#the-layout-engine)).

---

## The Layout Engine

**Files:** `Sources/Chai/Core/LayoutTypes.swift`, `Sources/Chai/Core/View.swift` (SPI), `Sources/Latte/Layout/Stacks.swift`, `Sources/Latte/Layout/Frame.swift`, `Sources/Chai/Renderer/Renderer.swift`, `Sources/Chai/Renderer/CellBuffer.swift`

The layout engine is the phase-4 **allocation** path (UPGRADE.md, "Phase 4"), now under the phase-5 **hard-box** contract. Phase 1 introduced the declarative view tree — ``View`` with `associatedtype Body`, `Model` inheriting ``View``, ``@ViewBuilder`` producing structural views — and rendered it by eagerly resolving the tree to a ``ViewOutput`` string. Phase 2 introduced a SwiftUI-style **proposal-driven** engine (measure, then place). Phase 4 replaced the negotiation with **top-down allocation** — *children report; parents decide*: `_measure(in:)` is a pure query (used for buffer sizing and child allocation, never binding), and one allocation walk (`_embed(into:at:)`) hands every view an explicit rect. What survives from the proposal model is only the **query language** (`AvailableSize`), not render-pass bookkeeping.

### The measure/render flow

```
renderer.write(model.body)          stores the tree: pendingView: any View
        │
        ▼  (every 1/fps seconds)
renderer.flush()
        │
        ├─ 1. query the tree (pure, read-only):
        │       view._measure(in: AvailableSize(width: w, height: altScreen ? h : nil))
        │       (width only inline — the buffer is content-sized; fixed size in alt screen)
        │
        ├─ 2. the query cascade: every view reports a ViewSize, delegating
        │       through `body` by default, overriding in containers/leaves
        │       (the report never binds — it sizes the buffer, nothing else)
        │
        ├─ 3. allocate the CellBuffer with the renderer's policies:
        │       empty content → 1-row buffer (invisible, keeps cursor tracking)
        │       alt screen    → fixed terminal size, wrap policy
        │       inline        → measured height clamped to termHeight, truncate policy;
        │                       suffix clamp via a negative row origin
        │
        ├─ 4. buffer.embed(view,
        │           at: ViewRect(origin: origin, size: (w, rootHeight)))
        │       ONE allocation walk: containers clamp child rects and embed via
        │       buffer.embed (hard-box clip); leaves paint at their rect's
        │       origin and are clipped to it
        │
        └─ 5. diff against lastBuffer (per-cell + eraseBelow) → paint changed rows
```

The eager bridge is gone (phase-4 P4b): ``View/_resolveToViewOutput()`` was deleted, and `body` is no longer a render path. Engine-implemented views (containers, structural views, wrappers, spacers, `Fill`) declare no body — `View.Body` defaults to ``Empty`` — while user composites keep `var body: some View`, whose engine defaults resolve through it. The allocation walk is the only renderer; see [The parity discipline](#the-parity-discipline) below for how the corpus became its mechanical spec.

### Who the engine SPI is for

The engine surface is four methods on ``View``:

```swift
func _measure(in available: AvailableSize) -> ViewSize   // pure query (report)
func _embed(into buffer: inout CellBuffer, at rect: ViewRect)  // allocation entrance
func _childViews() -> [any View]
func _flexibility() -> LayoutFlexibility
```

The underscore prefix is the SwiftUI-style convention for **technically public, not user-facing**. The methods are `public` for one reason: Latte's containers (`HStack`/`VStack`, `FrameView`) must call them across the module boundary — `internal` members of the `Chai` module are not visible to the `Latte` target. The prefix plus the doc framing marks them as SPI: regular users who write `body` with ``@ViewBuilder`` and use stacks and modifiers never touch them. The intended audience is **advanced users writing custom containers or layout-modifying views**. Everyone else is covered by the defaults: the protocol extension resolves `_measure(in:)`/`_embed` through `body` (so a view that only defines `body` measures and renders correctly with zero engine code), `_childViews()` defaults to `[self]` (so an ordinary composite view presents itself as one child), and `_flexibility()` defaults to `.rigid` (so an ordinary view never absorbs leftover space). Structural views (`TupleView`, `ForEachView`, `ConditionalContent`, `OptionalView`) override `_childViews()` — they are *transparent*, flattening their children so `for` loops and conditionals inside an `HStack` participate in horizontal layout — and flexible ``Spacer()`` overrides `_flexibility()`.

`_flexibility()` is what a stack consults to distribute **leftover main-axis space** (A2): a stack is *flexing* on its main axis when at least one child reports a positive fraction there, and it then fills a non-`nil` main-axis assignment, assigning each flexible child `rigid + Int(Double(leftover) * (fraction / totalFlex))` (normalized shares; the truncation remainder stays unallocated at the trailing end). With no flexible child the stacks take their pre-A2 code path unchanged.

### Query and allocation semantics

The query language is the **measurement context**, not render-pass bookkeeping. Three
properties matter; the first two replaced their phase-2/3 negotiation
counterparts.

**1. A report, not a bound; the rect is the box.**

"Hardness" lives at four distinct stages, and the third is the hard box:

| Stage | Who decides | Nature |
|-------|-------------|--------|
| The query (`AvailableSize`) | the parent | **context** — the size the parent is asking about |
| The report (`ViewSize`) | the child | the child's **truthful size** — may exceed the query context |
| The allocated `ViewRect` in `_embed` | the parent | the **decision** — the child's layout *and painting* box (phase 5) |
| The `CellBuffer` bounds | the renderer | the final backstop — writes outside the buffer are dropped |

Nothing clamps a report. A clamped answer destroys information a parent needs:
a scroll viewport must know that its content extends past the visible area even
though the visible area is all it can show. The parent may overrule a report
when it allocates (`Fill`-by-type, the `Text` compression floor), but the report
itself stays honest.

**Phase 5 made the rect a hard box.** Containers clamp child rects to their own
allocation, and the kernel intersects a clip with every `_embed` (``CellBuffer``
→ `embed(_:at:)`), so nothing a view paints can land outside its rect. The
buffer is now the final backstop, not the mechanism that bounded overflow.

**2. Query context, not a limit.**

The query is an *argument* to the child's measurement, not a limit on its
answer. It earns its keep the moment a child's answer *depends* on the context.
Views fall into a taxonomy by how they treat it:

- **Reporters** — leaves such as ``ViewOutput`` and fixed ``Spacer(lines:)``/``Spacer(columns:)``. They answer their intrinsic size; a `ViewOutput` is a fully-formed raster and ignores the query, while a fixed spacer answers its requested cells.
- **Containers** — ``VStack``/``HStack`` query their children in their own allocation context (cross-axis width/height, `nil` on the main axis), then allocate rects from the answers plus their rules (alignment, flexibility shares, the `Fill` remainder). The query is not a promise about the rect.
- **Allocators** — ``FrameView``. Fixed dimensions are allocation data: the frame owns them and hands the child that box verbatim; flexible dimensions pass the parent's assignment through (floored by the child's report when the assignment is degenerate).
- **Consumers** — query-sensitive views. ``Text`` wraps at the width it is **allocated** (with the compression floor); ``Fill`` claims the rect it is allocated; a flexible ``Spacer()`` reports 0×0 rigidly and a positive `_flexibility()` fraction so a stack can hand it a share of the leftover.

**3. The rect is the contract.**

There is no second pass to keep in sync: the rect passed to a child's
``View/_embed(into:at:)`` **is** the parent's decision — and, since phase 5, the
child's painting bound. The consequences are
the AGENTS.md engine pitfalls:

- `_measure(in:)` is a **pure report** — never treat an answer as binding; a
  container may overrule it.
- Containers allocate child rects from their own rules and query context;
  there is no remembered query value to re-measure with.
- `_embed` must not depend on `body` for containers.

The test-local ``RectEchoView`` pins that a child observes its *allocated* rect,
not the container's rect or an earlier query context. (The phase-3
`ProposalEchoView` and the A0 fit/render value-equality rule were deleted with
the negotiation engine.)

**Known nuance (PR #22 review):** in an `HStack`, a custom child that both
reports height-flexibility and paints observes the allocation-time height
context (`rect.size.height`) rather than the top-level query context (`nil`).
Built-ins are unaffected (spacers and `Fill` paint nothing); the
allocation-time context is the accurate one.

### Minimum queries (`AvailableSize.zero`)

SwiftUI's `ProposedViewSize` has three special cases: `unspecified` (ideal), `zero` (minimum), and `infinity` (maximum). Chai has the first two. `AvailableSize.zero` is the query context a container uses to ask for a child's **narrowest producible** form; it is a context, not a constraint — the report is never clamped.

Most views answer their minimum *by construction*: a `ViewOutput` is a fully-formed raster and answers its ideal size (it may legitimately exceed the zero context), fixed `Spacer(lines:)`/`Spacer(columns:)` answer their requested cells, flexible `Spacer()`/`Empty` answer 0×0, and `Fill` answers the queried rect (`(0, 0)` at `.zero`). `Text` is the one *compressible* view: at a zero (or negative — clamped to zero, one rule) width context it wraps to its minimum width, computed as the widest single character in the content (1 for ASCII-only, 2 if any wide/CJK character is present, at least 1 for non-empty content; empty content stays 0×0). The query and the allocated-width wrap resolve the minimum through the same function (``Text/minimumWrapWidth()``), so a `.zero` query and a degenerate allocation agree.

Containers follow their normal query rules at `.zero` — no special-casing. `VStack` queries children with `(0, nil)`, so it composes true minimums (max of the children's min-widths, Σ of their min-heights). `HStack` queries with `(nil, 0)`: it measures columns at *ideal* width, so a `Text` child reports its ideal width, not its minimum — a documented consequence of the column model, pinned by test rather than "fixed" (and the use-case-gated HStack-remaining-width candidate in UPGRADE.md). `FrameView` answers fixed dimensions verbatim and fills the (non-`nil`) zero assignment on flexible axes.

### Why there is no `.infinity`

The third SwiftUI special case is deliberately absent, for two independent reasons:

| Reason | Detail |
|--------|--------|
| No representation | A query dimension is `Int?`; there is no value for "infinity". |
| No faithful answer | `ViewSize` is `Int`-based, so a view could never answer a maximum faithfully — a flexible `Spacer()`'s maximum is "whatever the container decides is left", which is a *container-level* fact the child does not know. |

The functionality maps onto mechanisms that already exist: "expand to fill" ≙ `_flexibility()` + the stack's leftover distribution; "measure the maximum" ≙ the container's own leftover math. `.infinity` would add a third query case with no way to answer it — so it stays out.

### The parity discipline

The allocation engine is the only renderer; the corpus is its mechanical spec. That discipline is why the phase-4 rearchitecture could be an internals rewrite with no user-facing break:

- **The corpus** (`Tests/LatteTests/LayoutParity/ParityCorpus.swift`) is a named set of view trees — stacks, nesting, alignment, styling, CJK width, `for` loops, conditionals, `frame()`, wrappers — each pinned with the *visible rows* the engine produces (`expectedRows`). The corpus exists because the **first engine attempt failed precisely because nothing exercised it**: the seam was reworked blind, and the flaw (operating on resolved outputs instead of child views) was only caught when the whole thing was reverted and redesigned. Every engine change is verified against this mechanical spec, never against hand-waving; no case is skipped.
- **Comparison semantics:** buffers are compared as *visible row text*, not raw cells. `visibleRows(_:)` skips zero-width cells (wide-character continuations, combining marks), counts a width-2 cell once, and right-strips trailing spaces so all-space rows normalize to `""`. Raw cell equality is intentionally too strict: alignment writes space cells where a leaf leaves cells `.empty` — both render identically under `eraseLineRight`.
- **The historical divergence list is closed (P4b).** The ten entries below recorded where the phase-2/3 engine legitimately differed from the eager `body` join. When P4b deleted the eager path, the comparison itself retired: entries #4–#10 are gone with it, and #1–#3 are simply engine semantics, pinned by the corpus. Kept here as history:
  1. `Spacer(lines:)` inside a `VStack`: the engine produces exactly N blank rows; the eager path doubled them (a join quirk; the engine semantics are preserved).
  2. `.empty` vs space cells in alignment padding — invisible by construction.
  3. Multi-line children block-aligned under non-left `VStack` alignment: the engine aligns each child as one layout unit; the eager path aligned each line (an artifact of text joining). SwiftUI-consistent.
  4. `frame()` flexible-fill existed only in the engine: a `nil` frame dimension fills a non-`nil` assignment, which the eager `body` could not express. Retired in P4b.
  5. Proposal-consuming `Text` wraps instead of truncating (A1). Retired in P4b.
  6. A fixed-width `frame()` around `Text` wraps instead of overflowing (A1). Retired in P4b.
  7. `FlexibleSpacer` distributed leftover space only in the engine (A2); now `Spacer()`. Retired in P4b.
  8. `Fill` claims the proposed dimensions only in the engine (A2). Retired in P4b.
  9. `.clipped()` masked overflow only in the engine (A3). Retired in P4b; phase 5 made clipping the default (the rect is the box) and removed `.clipped()`.
  10. Newline-only `Text` collapses to nothing (pinned during the PR #21 review). Retired in P4b.

The suites: `ParityEngineTests` (every corpus case against `expectedRows`) and `ParityHarnessTests` (pins the comparison semantics themselves). `ParitySpecTests` and `eagerBuffer` retired with the eager path in P4b.

### `frame()` — one modifier

The phase-1 eager ``ViewOutput.frame(width:height:horizontalAlignment:verticalAlignment:)`` (minimum-enforcing, returning a raster) and the tree-based ``View.frame(width:height:horizontalAlignment:verticalAlignment:)`` coexisted during phase 2. **P4b retired the eager overload**: every receiver — including `ViewOutput` — now uses the tree-based frame, whose fixed dimensions are exact allocations. Since phase 5, the frame is also a **hard box**: content larger than the frame is clipped to it. See ``FrameView``.

### Scope: what the engine deliberately does not do

Phase 3/4's declarative features (wrapping `Text`, fill/flex views, `AnyView`, tree-preserving modifier wrappers) deliberately avoid SwiftUI's hardest machinery: there is **no view identity** and **no per-view diffing**. The Elm model re-renders full frames every tick and the only history the framework keeps is the `CellBuffer` from the last frame for cell-level row diffing. This is a core simplification, not a gap: a full-frame layout pass at terminal frame rates is cheap enough that identity tracking buys nothing. Any design that introduces identity or structural diffing on the view tree should be treated as scope creep and justified separately.

---

## Spices — Component Library

**Path:** `Sources/Spices/`

Spices provides pre-built, reusable interactive components built on top of Chai's Elm Architecture. Each component is a `struct` conforming to Chai's `Model` protocol (or designed to be embedded within a parent model); since phase 1 they expose their UI through `var body` (a `View` tree), not a `view()` method.

### Components

| Component | File | Description |
|-----------|------|-------------|
| **TextInput** | `TextInput/TextInput.swift` | Single-line text input with cursor navigation, character limits, and focus/blur support. |
| **TextArea** | `TextArea/TextArea.swift` | Multi-line text editing. |
| **List** | `List/List.swift`, `List/FilterDelegate.swift` | Scrollable, selectable list with optional filtering/search. |
| **SelectableList** | `SelectableList/SelectableList.swift` | Selectable list with rune-based selection state (used by the GroceryList example). |
| **Menu** | `Menu/Menu.swift` | Interactive menu with keyboard navigation and selection messages. |
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
| **Style** | *(defined in Latte — see `Sources/Latte/Style/`)* | `Style`, `Color`, and `ColorProfile` are provided by the Latte module. Import `Latte` to use them directly. |

### Internal Utilities

| File | Purpose |
|------|---------|
| `Internal/IDGenerator.swift` | Unique ID generation for component instances. |
| `Internal/StyleBridge.swift` | `Style.styledText(_:)` — builds ``StyledText`` from styled strings without raw ANSI bytes (the safe path for `ViewOutput` content). |

### Design Notes

- **Depends on Chai and Latte.** Spices imports `Chai` for the `Model`, `Message`, `Command`, and `KeyMsg` types, and imports `Latte` for `Style`, `Color`, and `ColorProfile`.
- **Composable.** Components are value types that can be embedded as fields within a parent model's `struct` and updated by delegating messages.
- **Terminal-safe colors.** `ColorProfile.detect()` reads environment variables (`NO_COLOR`, `COLORTERM`, `TERM_PROGRAM`, `TERM`) and TTY state to determine color capability. `Style.render(_:profile:)` automatically downsamples colors to the detected profile, preventing garbled output on lower-capability terminals. The detection function accepts injectable parameters for unit testing without touching the real environment.

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
    ├─► renderer.write(model.body)   [view tree → layout engine]
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
model.body (view tree, stored as pendingView: any View)
        │
        ▼
renderer.write(view)   stores the tree, defers layout
        │
        │  (every 1/fps seconds, on actor executor)
        ▼
renderer.flush()
        │
        ├─ cursor visibility (show/hide)
        │
        ├─ query terminal size (report only):
        │     view._measure(in: AvailableSize(width: w, height: altScreen ? h : nil))
        │
        ├─ allocate CellBuffer by policy:
        │     empty content?   → 1-row buffer
        │     alt screen?      → fixed terminal size, wrap policy
        │     inline?          → measured height clamped to termHeight, truncate policy
        │                      → suffix clamp via negative row origin
        │
        ├─ buffer.embed(view,
        │       at: ViewRect(origin: origin, size: (w, rootHeight)))
        │     rootHeight = bufferHeight (alt screen) | measured.height (inline)
        │     (one allocation walk — the root rect is the assignment and the
        │      kernel clip; each container decides its children's rects)
        │
        ├─ diff vs lastBuffer (per-cell changes + eraseBelow)
        │     no changes?      →  skip content flush
        │
        ├─ move cursor to top of previous render
        ├─ flush queuedLines (println, normal screen only)
        │
        ├─ for each row:
        │     unchanged cell?  →  skip (emit \n only)
        │     changed?         →  write row + ESC[K
        │
        ├─ prevHeight > newHeight? →  ESC[J (erase below)
        │
        └─ park cursor
                │
                ▼
        wrap with synchronized output markers (mode 2026)
        terminal.write(assembled ANSI string)
```

The content output is wrapped with synchronized update markers (`ANSI.beginSyncUpdate` / `ANSI.endSyncUpdate`, mode 2026) to prevent partial-frame tearing on supporting terminals. Terminals that do not support mode 2026 silently ignore these sequences. Terminal state transitions (alt screen enter/exit, window title, cursor visibility) are written outside the sync markers since they are brief, non-visual operations that do not cause tearing.

The renderer diffs **both rendered cells and terminal state** between frames. Terminal state is no longer carried inside the view tree (phase 1 split): alt screen is a ``Program`` option, window title is a ``Command``, and the cursor is the model's ``cursor`` property. Transitions are emitted only when values change — e.g. the cursor shape/blink is diffed against `lastCursor`, and `setWindowTitle` records `lastWindowTitle`.

The key content optimisation is **cell-level diffing via `CellBuffer`**: only rows containing changed cells are rewritten. This minimises the number of bytes sent to the terminal, which matters for slow connections (SSH) and large UIs. On the first frame (empty `lastBuffer`) every row is rewritten so blank rows left by vertical centering are not mistaken for "unchanged" and old content cannot ghost through.

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
    ├─ renderer.write(model.body) + renderer.flush()
    │
    ├─ [event loop] ──────────────────────────────────────────┐
    │       for await msg in messageStream                     │
    │           handleRendererMessage(msg)                     │
    │           model.update(msg) → cmd                        │
    │           renderer.write(model.body)  → view tree        │
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

Tests use Swift Testing (`@Test`, `#expect`) across three test targets: **1278 tests in 110 suites**, all green. `swift build` alone does not compile tests — the gate must run `swift test`.

### ChaiTests (Tests/ChaiTests/)

| Test file | Coverage |
|-----------|----------|
| `InputParserTests.swift` | All named keys, arrows (plain/Shift/Ctrl/Ctrl+Shift), F1–F20, SS3, Ctrl+letter (incl. named-before-generic ordering), Alt, printable UTF-8, rune batching, incomplete sequences (`canHaveMoreData`), unknown sequences |
| `RendererTests.swift` | Renderer via `MockTerminalOutput` (a `TerminalOutput` conformance that captures written strings): initial render, cell-diff skipping, alt screen enter/exit, cursor hide/show, window title, `println`, `repaint`, terminal size clamping, synchronized output markers, ANSI-aware width truncation, cursor shape |
| `RendererEnginePathTests.swift` | The M3 flip: the engine-built buffer path (inline truncate, alt-screen wrap, empty→1-row, suffix clamp, diff/paint) |
| `RendererStructuralTests.swift` | The renderer accepting structural view trees (stacks, `for` loops, conditionals) via `write(_ view: View)` |
| `LayoutEngineTests.swift` | M1/M2 engine units, re-roled for phase 4: `_measure(in:)`/`_embed`/`_childViews` on leaves and Latte containers, allocation rects, fraction math |
| `FlexibilityTests.swift` | A2: the `_flexibility()` SPI (default `.rigid`), `LayoutFlexibility`, and the unified `Spacer`/`Fill` primitives (flexible 0×0 measurement with a fraction, fixed cell counts, no-op render) |
| `AnyViewTests.swift` | PB: `AnyView` forwards all four SPI methods — measurement, allocation, `_childViews` structural transparency, and `_flexibility` leftover distribution — plus heterogeneous `for` loops and `buildArray` |
| `CellBufferTests.swift` / `CellTests.swift` | Buffer write policy (wrap vs truncate), wide-character invariants, diff, `Cell` values |
| `StyledTextTests.swift` | Styled text segments, `maxLineWidth`, `lineCount()`, interpolation |
| `StructuralViewTests.swift` | `TupleView`/`ForEachView`/`ConditionalContent`/`OptionalView` flattening and `_childViews()` transparency |
| `CommandTests.swift` | `.perform`, `.batch`, `.sequence`, `.quit`, `.tick`, `.every`, `.println`, `.setWindowTitle`, integration |
| `ANSIHyperlinkTests.swift`, `KeyTypeTests.swift`, `MessageFilterTests.swift`, `EventFilterTests.swift`, `LoggingTests.swift`, `ProgramTests.swift` | OSC 8 hyperlinks, key type equatable, internal message/event filtering, logging, program lifecycle |

### LatteTests (Tests/LatteTests/)

Covers the string-level layout/styling modules plus the phase-2 engine:

| Test file | Coverage |
|-----------|----------|
| `DisplayWidthTests.swift` | Character width, ANSI-aware visible width, truncation |
| `BorderTests.swift` | All border styles, selective sides, ANSI preservation, equatable |
| `AlignmentTests.swift` | Left/center/right/fractional alignment, ANSI-aware padding, multi-line |
| `PaddingTests.swift` | All-sides padding, shorthand constructors, custom fill characters, ANSI preservation |
| `SizeTests.swift` | Width/height measurement, enforce/clamp dimensions, ANSI awareness |
| `WrapTests.swift` | Word wrapping at spaces/hyphens/commas, wide characters, ANSI carry-over |
| `InlineTests.swift` | First-line extraction, ANSI preservation, composition with other functions |
| `JoinTests.swift` | Horizontal/vertical joins, alignment options, ANSI preservation |
| `CompositorTests.swift` | Z-ordered `Layer` canvas placement |
| `StringExtensionTests.swift` | Chainable string extensions, composition chains |
| `TabExpansionTests.swift` | Tab-stop alignment, custom widths, ANSI interaction |
| `StackTests.swift` / `StacksEngineTests.swift` | Engine measure/render of `VStack`/`HStack` through the allocation walk, alignment, skip-empty, styling survival |
| `FrameTests.swift` | M4 `frame()`: fixed/one-dim/ideal/alignment/nesting, hard-box clipping, degenerate sizes |
| `HardBoxTests.swift` | Phase-5 containment: frame clips a wrapped status line, custom views cannot paint outside their rect, child rects are clamped to the parent, wide-char clip boundaries, clip restoration, nested boxes |
| `SpacerAndFillTests.swift` | Leftover distribution in `VStack`/`HStack` (fill a non-`nil` main-axis assignment, normalized shares, odd-remainder truncation, `fraction: 0` rigid, nil assignment content-sized) and `Fill` in stacks/frames |
| `LayoutParity/` | The corpus-based discipline: `ParityHarness.swift` (`embedBuffer` + `visibleRows`), `ParityCorpus.swift` (the single-spec engine corpus), `ParityEngineTests` (every case against `expectedRows`), `ParityHarnessTests` (comparison semantics) |
| `ModifierWrapperTests.swift` | P4a tree wrappers: padding/margin/border shrink-wrap, bounded child query, inset placement, `.beside`/`.above`, flexibility forwarding |
| `ViewOutputLayoutTests.swift` | The `ViewOutput` raster helpers (`.clampedWidth()`, `.clampedHeight()`), including wide characters and multi-line content |
| `StyleTests.swift`, `StyleFlagTests.swift`, `UnderlineStyleTests.swift`, `ColorUtilitiesTests.swift`, `HyperlinkTests.swift`, `ListRendererTests.swift`, `TreeRendererTests.swift` | Styling, color utilities, hyperlinks, static renderers |

### SpicesTests (Tests/SpicesTests/)

| Test file | Coverage |
|-----------|----------|
| `SpicesTests.swift` | Component initialization, state management, view rendering (via `body`), key binding matching, style rendering |

> **Note:** `SpicesTests.swift` currently emits deprecation warnings for `Progress.viewAs(_:)` in its progress-bar cases — pre-existing, out of phase-2 scope; the suites still pass. Migrating them to `viewAsStyledText(_:)` is tracked separately.

---

## Package Layout

```
chai/
├── Package.swift                        # swift-tools-version: 6.1
│                                        # macOS 14+, StrictConcurrency enabled
│                                        # swift-docc-plugin (build-time only)
│
├── Sources/
│   ├── Chai/                            # Core TUI framework
│   │   ├── Chai.swift                   # Module documentation entry point
│   │   ├── Core/
│   │   │   ├── Model.swift              # Model protocol (inherits View)
│   │   │   ├── Message.swift            # Message protocol + built-in messages
│   │   │   ├── Command.swift            # Command enum + convenience factories
│   │   │   ├── Program.swift            # Program<M>, ProgramRunner, SignalHandler
│   │   │   ├── Program+Options.swift    # Program.Option (withAltScreen, withLogger, ...)
│   │   │   ├── View.swift               # View protocol + layout engine SPI + Text/Spacer/Fill/Empty
│   │   │   ├── AnyView.swift            # Type erasure (forwards all four SPI methods)
│   │   │   ├── ViewBuilder.swift        # @resultBuilder → structural view tree
│   │   │   ├── StructuralViews.swift    # TupleView/OptionalView/ConditionalContent/ForEachView
│   │   │   ├── ViewOutput.swift         # Terminal leaf (styled text) + interpolation
│   │   │   ├── LayoutTypes.swift        # AvailableSize / ViewSize / ViewOrigin / ViewRect / LayoutFlexibility
│   │   │   ├── Cursor.swift             # Cursor position and shape
│   │   │   ├── Logger.swift             # ChaiLogger / FileLogger diagnostics
│   │   │   └── MessageChannel.swift     # AsyncStream wrapper for the message bus
│   │   ├── Terminal/
│   │   │   ├── ANSICodes.swift          # ANSI/VT100 escape sequence constants
│   │   │   ├── Terminal.swift           # TerminalOutput protocol + Terminal class
│   │   │   ├── InputReader.swift        # Async stdin reader (background Thread)
│   │   │   └── InputParser.swift        # Pure byte-sequence parser → KeyMsg
│   │   └── Renderer/
│   │       ├── Renderer.swift           # Actor-based framerate diff renderer (engine flush)
│   │       ├── Cell.swift               # Cell value (character, style, wide-width invariants)
│   │       ├── CellBuffer.swift         # 2D cell grid + write policy + diff
│   │       ├── StyledText.swift         # Structured styled text (maxLineWidth, lineCount)
│   │       └── DisplayWidth.swift       # Unicode-aware visible width (Chai copy)
│   │
│   ├── Latte/                           # Layout, styling, and the declarative containers
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
│   │   │   ├── Inline.swift             # First-line extraction
│   │   │   ├── Stacks.swift             # VStack/HStack (allocation engine impl)
│   │   │   ├── Frame.swift              # FrameView + View.frame(...) modifier
│   │   │   ├── PaddingView.swift        # .padded / .margined wrapper
│   │   │   ├── BorderView.swift         # .bordered wrapper
│   │   │   └── CompositionWrappers.swift # .beside / .above stack sugar
│   │   ├── Composition/
│   │   │   ├── Join.swift               # Horizontal/vertical block joining
│   │   │   └── Compositor.swift         # Z-ordered Layer canvas placement
│   │   ├── Measurement/
│   │   │   └── DisplayWidth.swift       # Unicode-aware visible width (Latte copy)
│   │   ├── Static/
│   │   │   ├── ListRenderer.swift       # Static list rendering
│   │   │   └── TreeRenderer.swift       # Static tree rendering
│   │   ├── Utilities/
│   │   │   ├── TabExpansion.swift        # Tab-to-spaces expansion
│   │   │   └── StringLines.swift        # Line splitting utilities
│   │   └── Extensions/
│   │       ├── String+Layout.swift      # Chainable String extensions
│   │       ├── StyledText+Layout.swift  # StyledText layout extensions
│   │       └── ViewOutput+Layout.swift  # ViewOutput raster clamping helpers
│   │
│   └── Spices/                          # Component library (depends on Chai, Latte)
│       ├── Spices.swift                 # Module entry point
│       ├── TextInput/TextInput.swift    # Single-line text input
│       ├── TextArea/TextArea.swift      # Multi-line text editing
│       ├── List/
│       │   ├── List.swift               # Selectable list with filtering
│       │   └── FilterDelegate.swift     # Filter behavior delegate
│       ├── SelectableList/SelectableList.swift  # Rune-based selectable list
│       ├── Menu/Menu.swift              # Interactive menu
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
│           ├── IDGenerator.swift        # Unique ID generation
│           └── StyleBridge.swift        # Style.styledText(_:) for safe ViewOutput content
│
├── Tests/
│   ├── ChaiTests/                       # InputParser, Renderer (+engine path, structural),
│   │   │                                # LayoutEngine, CellBuffer/Cell, StyledText,
│   │   │                                # StructuralView, Command, ANSIHyperlink, KeyType,
│   │   │                                # MessageFilter, EventFilter, Logging, Program
│   │   └── ...
│   ├── LatteTests/                      # all string layout modules + StackTests,
│   │   │                                # StacksEngineTests, FrameTests,
│   │   │                                # LayoutParity/ (harness + corpus + spec + engine),
│   │   │                                # ViewOutputLayoutTests, style/color/static suites
│   │   └── ...
│   └── SpicesTests/
│       └── SpicesTests.swift            # Component tests
│
└── Examples/
    └── GroceryList/
        └── Sources/
            └── main.swift               # Grocery list example app (centers via .frame(...))
```

**Package targets:**

| Target | Type | Dependencies | Description |
|--------|------|-------------|-------------|
| `Chai` | library | — | Core TUI framework (runtime, rendering, layout engine types + SPI) |
| `Latte` | library | Chai | Layout, styling, measurement, and the declarative containers |
| `Spices` | library | Chai, Latte | Pre-built interactive components |
| `ChaiTests` | test | Chai, Latte | Core framework + engine tests (exercise Latte containers) |
| `LatteTests` | test | Latte | Layout, styling, measurement, engine, and parity tests |
| `SpicesTests` | test | Spices | Component tests |
| `GroceryList` | executable | Chai, Latte, Spices | Example app (phase-2 acceptance feature) |

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

### Why cell-level diffing in the renderer?

Full-screen redraws on every frame would send a large number of bytes to the terminal, causing visible flicker on slow connections (SSH) and wasting CPU on ANSI parsing in the terminal emulator. Since M3 the diff operates on the `CellBuffer` instead of parsed strings — the renderer rebuilds the frame through the layout engine, diffs per cell, and only rewrites rows that contain changed cells. This typically reduces output by 90%+ for UIs that change only a few lines per frame.

### Why a child-*view* layout seam instead of a child-*output* seam?

The phase-1 renderer resolved children to `ViewOutput` strings before composing them (`_collectChildOutputs()`). The first phase-2 engine attempt kept that habit — layout operated on resolved outputs — and failed: resolving flattens the tree, bypasses every child's layout overrides, and makes the query context meaningless. The reverted attempt was the reason the M0 parity harness landed first, so the redesign could be verified against a mechanical spec. The engine's `_childViews()` seam exposes child *views* instead, letting containers measure and place them with full SPI fidelity.

### Why is the engine SPI underscored-but-public?

`_measure(in:)`, `_embed(into:at:)`, `_childViews()`, and `_flexibility()` are `public` because Latte's containers must call them across the module boundary — `internal` members of the `Chai` module are invisible to the `Latte` target. The underscore prefix is the SwiftUI convention for "technically public, not user-facing": the methods are SPI for advanced container authors, not part of the API ordinary model code relies on. Their protocol-extension defaults (`body`-resolving, `[self]` children, `.rigid` flexibility) keep every other view working with zero engine code.

### Why query *context* rather than clamped constraints?

A query is a report, not a wall: the child answers its truthful size, the parent decides the allocated rect, and the allocated rect — enforced by the kernel clip — is what bounds painting; the ``CellBuffer`` bounds are the final backstop. Clamping at query time is deliberately avoided because it destroys information — a scroll viewport must know its content is taller than the visible area even though it can only show part of it. Query-responsive children exist since phase 3 (wrapping `Text`), and in phase 4 they respond to the width they were **allocated** (`Text` wraps at `rect.size.width`, with the compression floor).

### Why assemble the entire frame into one `String` before writing?

Each `write(2)` syscall has overhead. Assembling the frame into a single string and writing it in one call minimises syscall count and ensures the terminal receives the frame atomically (no partial-frame flicker between syscalls).

### Why `DispatchSource` for signal handling, not `sigaction`?

`DispatchSource.makeSignalSource` integrates cleanly with Swift's concurrency model and GCD. It delivers signal events on a dispatch queue, where they can safely call `messageContinuation.yield`. Using `sigaction` with a raw C signal handler would require async-signal-safe code, which is extremely restrictive and incompatible with Swift's runtime.

### Why a sentinel message for `SIGWINCH`?

`SignalHandler` does not hold a reference to `Terminal` (separation of concerns). Rather than coupling them, `SignalHandler` sends a `WindowResizeSignalMsg` sentinel. `ProgramRunner` intercepts it in `handleRendererMessage`, queries the terminal size itself, and sends the resolved `WindowSizeMsg` to the model. The model never sees the sentinel.
