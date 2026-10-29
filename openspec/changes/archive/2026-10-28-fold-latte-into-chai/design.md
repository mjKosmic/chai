# Design

## Context

See `proposal.md` → Why. The current tree, after `retire-string-layout`:

- `Sources/Latte` contains 17 files: the tree containers and wrappers
  (`Layout/`), `Border` glyph sets (`Borders/`), styling (`Style/`), an internal
  width helper (`Measurement/`), tab expansion (`Utilities/`), and the module
  entry point.
- Every container file imports Chai. The styling files do not, but they expose
  `Style.textAttributes` (which returns Chai's `TextAttributes`) and
  `Style.render` (which returns an ANSI string for `Command.println`).
- `Chai/Core/View.swift` already owns the leaves (`Text`, `Spacer`, `Fill`,
  `Empty`), the `View` protocol, and the SPI. The renderer and parity corpus
  pin the allocation behavior.

The engine contract and parity discipline are described in `ARCHITECTURE.md` →
"The Layout Engine" and "The parity discipline"; this change does not alter
either.

## Goals / Non-Goals

**Goals:**

- Make `Chai` the single runtime and view/layout/styling module, with `Spices`
  as the optional component layer.
- Leave exactly one display-width implementation.
- Keep the engine SPI public as a supported extension point.
- Keep the parity corpus and every rendered row unchanged.

**Non-Goals:**

- Changing any layout, rendering, styling, or input behavior.
- Internalizing the SPI or introducing a separate low-level substrate module.
- Rewriting Spices bodies to use the tree DSL.
- Any test-count change beyond the target rename.

## Decisions

### 1. Fold; do not keep a compatibility shim

A `Latte` target that re-exported Chai would keep two products, two import
statements, and the package-level split for no behavioral gain. The pre-alpha
policy allows the import break. *Alternative considered:* leave `Latte` as a
one-line `@_exported import Chai` shim. Rejected: `@_exported` is underscored,
and the shim would outlive its usefulness immediately.

### 2. Keep the engine SPI public

`_measure`/`_embed`/`_childViews`/`_flexibility` and the layout value types stay
public. Custom containers are a supported extension point and the `view-api`
spec pins that. This change removes the *structural* need for public SPI (the
containers are now in the same module) but deliberately keeps the extensibility
one. *Alternative considered:* internalize and close the extension point.
Rejected: the docs, tests, and `view-api` spec treat it as supported.

### 3. Delete Latte's internal width helper

`BorderView` paints glyph cells by display width, and `expandTabs` tracks the
display column. Both move into Chai, where the internal `displayWidth(of:)`
already exists. Only the single implementation remains; the duplicate file is
deleted rather than moved.

### 4. Rename the test target instead of merging

`LatteTests` becomes `ChaiViewTests` (363 tests across the layout, styling,
parity, and simple-path suites). Merging it into `ChaiTests` would move roughly
4,000 lines and bury the parity corpus inside the runtime suite. Keeping a
second `Chai`-only test target preserves build parallelism and keeps the
mechanical engine spec visible. *Alternative considered:* one test target.
Rejected for review clarity.

### 5. One module entry point

`Sources/Chai/Chai.swift` remains the module doc. The surviving parts of
`Latte.swift` (styling, containers, styled borders, tab expansion) are folded
into it, and the Latte module file is deleted. There is no second module doc to
keep in sync.

### 6. File placement inside Chai

```
Sources/Chai/
  Core/      runtime, View/DSL leaves, ViewOutput, clamping helpers
  Layout/    Stacks, Frame, PaddingView, BorderView, CompositionWrappers,
             Alignment (value types), Border (glyph sets)
  Style/     Style, Style+TextAttributes, Color, ColorProfile, ColorPalette,
             ColorUtilities
  Utilities/ TabExpansion
  Renderer/  Renderer, CellBuffer, Cell, StyledText, DisplayWidth, Wrapping
  Terminal/  ...
```

Moved files drop their `import Chai` (same module). Files keep their current
contents otherwise.

## Risks / Trade-offs

- **Import break for `import Latte` users.** → Marked **BREAKING** in the
  proposal and changelog; the replacement is `import Chai`. No shim by design.
- **A moved file keeps `import Chai` and fails to build.** → The build fails
  immediately; task 2 verifies `swift build` after each move group.
- **The test-target rename leaves stale paths in CI or docs.** → CI runs bare
  `swift test`, which discovers targets from `Package.swift`; the docs and
  `Package.swift` are updated in the same change.
- **Behavior drift while moving files.** → The parity corpus (`expectedRows`)
  and the full test suite are the gate; no expectation is changed.
- **Duplicate `RectEchoView` helpers.** → They remain in two test targets; only
  their "cannot see this file" comments need the new target name.

## Migration Plan

No persistent state. Source migration:

| Before | After |
|---|---|
| `import Latte` | `import Chai` |
| `.product(name: "Latte", package: "chai")` | remove |
| `Latte` target dependency in a manifest | `Chai` |

Rollback is a revert of the change; no runtime or schema state is involved.

## Open Questions

None.
