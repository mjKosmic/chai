<p align="center">
  <img src="docs/assets/logo.svg" width="128" alt="Chai: a chai cup with a shell prompt rising as steam">
</p>

# Chai

A Swift-native terminal UI (TUI) framework built on the **Elm Architecture**
(Model–Update–View) and inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea).
It uses Swift concurrency (`async`/`await`, actors, `AsyncStream`) and has no
runtime dependencies.

```swift
import Chai

struct Counter: Model {
    var count = 0

    func initialize() -> Command? { nil }

    mutating func update(_ msg: any Message) -> Command? {
        guard let key = msg as? KeyMsg else { return nil }
        switch key.type {
        case .up:        count += 1
        case .down:      count -= 1
        case .ctrl("c"): return .quit
        default:         break
        }
        return nil
    }

    var body: ViewOutput {
        "Count: \(count)\n\nPress ↑/↓ to change, Ctrl+C to quit.\n"
    }
}

@main struct App {
    static func main() async throws {
        try await Program(Counter()).run()
    }
}
```

## Styling

Styles are modifiers on any view — a leaf, a container, or a whole subtree —
and `Color` is the one color value for both view modifiers and inline text:

```swift
VStack {
    Text("Groceries").bold()
    HStack {
        Text("milk").fg(.green)
        Spacer()
        Text("2").dim()
    }
}
.padded(1)
.bg(.brightBlack)
.bordered(.rounded, borderStyle: Style().foreground(.cyan))
.frame(width: 40, horizontalAlignment: .center)
```

An outer style fills only the properties an inner style left unset, so the
innermost color wins while text attributes accumulate. A background covers the
view's whole occupied rect, including internal spaces, and styling never
changes layout: measurement, wrapping, and the allocated rect are identical
with or without a style. Styling is carried as structured cell metadata; ANSI
strings are produced only for out-of-band output such as `Command.println`.

## Modules

| Module | Purpose |
|--------|---------|
| **Chai** | Elm Architecture runtime, input handling, rendering, the view tree, layout containers/modifiers, and styling (`Style`/`Color`/`ColorProfile`) |
| **Spices** | Ready-made components: text input, list, menu, table, spinner, timer, file picker, and more |

## Requirements

- **Swift 6.1+** (`swift-tools-version: 6.1`)
- **macOS 14+**

There are no runtime dependencies. `swift-docc-plugin` is declared for
build-time documentation generation only.

## Installation

Add Chai to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mjKosmic/chai", branch: "main")
]
```

Then depend on the products you need:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "Chai", package: "chai"),
        .product(name: "Spices", package: "chai"),
    ]
)
```

## Build & Test

```bash
swift build          # build the libraries and the GroceryList example
swift test           # run all tests (Swift Testing)
swift build && swift test
```

## Documentation

- [`docs/README.md`](docs/README.md) — documentation index: design, history,
  and where behavior specs vs. migration history live.
- [`openspec/specs/`](openspec/specs/) — OpenSpec behavior specifications, the
  source of truth for current system behavior.
- [`openspec/changes/`](openspec/changes/) — active change proposals; completed
  changes are archived under [`openspec/changes/archive/`](openspec/changes/archive/).
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — design of record: the Elm loop,
  renderer, input pipeline, concurrency model, and the allocation layout engine.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — prioritized, sequenced plan for
  high-impact improvements.
- [`docs/history/VIEW-LAYER-MIGRATION-LOG.md`](docs/history/VIEW-LAYER-MIGRATION-LOG.md) — migration history and phase plans (through the
  phase-5 hard-box contract and the SPI rename).
- [`docs/history/PHASE-4-TOP-DOWN-ALLOCATION-SPIKE.md`](docs/history/PHASE-4-TOP-DOWN-ALLOCATION-SPIKE.md) — historical phase-4 spike report.
  The phase-4 kickoff handoff is preserved in the archived change at
  [`openspec/changes/archive/2026-10-27-phase-4-top-down-allocation/design.md`](openspec/changes/archive/2026-10-27-phase-4-top-down-allocation/design.md).
- [`AGENTS.md`](AGENTS.md) — contribution guide for AI agents (build rules,
  coding conventions, pitfalls).

## Spec-driven development

**All changes require an OpenSpec change** — features, fixes, refactors, tests,
docs, CI, and release chores. There are no direct-to-`main` edits. Behavior
specs live in `openspec/specs/<capability>/spec.md`; proposed work lives in
`openspec/changes/<change>/` with a proposal, delta specs, design, and tasks.
A pure refactor, tooling, or docs change with no observable behavior delta sets
`skip_specs: true`. The canonical policy is [`AGENTS.md`](AGENTS.md) and the
artifact/enforcement guide is [`openspec/README.md`](openspec/README.md).
Archive the change inside the same pull request before merge; never push
directly to `main`. Archiving a change merges its deltas into the main specs
and preserves the change under `openspec/changes/archive/`.

The workflow is available as OpenSpec skills and commands in `.opencode/` and
`.claude/`. In OpenCode, use `/opsx-propose`, `/opsx-apply`, and
`/opsx-archive`; in Claude Code, the equivalents are `/opsx:propose`,
`/opsx:apply`, and `/opsx:archive`. Those skills invoke the `openspec` command,
so install the CLI first (`brew install openspec` or
`npm install -g @fission-ai/openspec@latest`). The examples below use `npx` so
they work before a global install.

```bash
npx -y @fission-ai/openspec@latest list --specs
npx -y @fission-ai/openspec@latest list
npx -y @fission-ai/openspec@latest validate --all --strict
```


The example app lives in
[`Examples/GroceryList/Sources/main.swift`](Examples/GroceryList/Sources/main.swift).

## Status

Pre-alpha. The API is still allowed to change; breaking changes are documented
in `docs/history/VIEW-LAYER-MIGRATION-LOG.md`.

## License

Chai is released under the MIT License. See [`LICENSE`](LICENSE) for the full
text.
