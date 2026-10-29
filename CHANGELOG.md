# Changelog

All notable changes to Chai are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Pre-1.0 releases may contain breaking changes; the migration history lives in
[`docs/history/VIEW-LAYER-MIGRATION-LOG.md`](docs/history/VIEW-LAYER-MIGRATION-LOG.md).

## [Unreleased]

### Added

- View styling modifiers on every `View`: `.fg(_:)`, `.bg(_:)`, `.bold()`,
  `.dim()`, `.italic()`, `.underline()`, `.strikethrough()`, and
  `.styled(_ style: Style)`. A modifier applies to the cells its subtree
  paints; outer modifiers fill only the properties inner ones left unset, so
  the innermost color wins while text attributes accumulate, and a background
  covers the view's occupied rect. Styling never changes measurement,
  wrapping, or allocation.
- Named ANSI colors on `Color` (`.black`, `.red`, ... `.brightWhite`) and a
  `Color(_ cellColor: CellColor)` bridge for low-level cell code.
- A `TextAttributes` convenience initializer taking `Color` foreground and
  background values.

### Changed

- **BREAKING** `StyledText.fg(_:)` and `.bg(_:)` now take `Color` instead of
  `CellColor`. Named-color call sites (`"x".fg(.red)`) compile unchanged;
  migrate explicit cell-level colors with the named `Color` value or
  `Color(CellColor.red)`.
- **BREAKING** Removed the `Latte` library product and target. `VStack`,
  `HStack`, `FrameView`, the padding/border modifiers, `Style`, `Color`,
  `ColorProfile`, `Border`, and tab expansion are now part of `Chai`. Replace
  `import Latte` with `import Chai` and remove the `Latte` product from your
  package dependencies.
- `Style.textAttributes` and `Style.styledText(_:)` are now part of `Chai`
  (previously `Spices`/`Latte`), so styling values convert to cell attributes
  without importing the component library.
- `.bordered` preserves styled borders through per-side `Style?` parameters,
  replacing the styling that the string border renderer provided.
- `expandTabs` and `String.tabsExpanded()` are retained as text preparation:
  tabs have no display width and are skipped by the cell renderer.

### Removed

- **BREAKING** Removed the string-level layout API. Layout is expressed
  through the view tree; the pre-alpha policy allows this source break
  without a deprecation cycle.
  - `pad` / `margin` / `String.padded` / `String.margined` →
    `.padded` / `.margined` on the view
  - `border` / `String.bordered` → `.bordered(...)`, which now accepts
    `borderStyle`, `topStyle`, `bottomStyle`, `leftStyle`, and `rightStyle`
  - `align` / `String.aligned` → `.frame(width:horizontalAlignment:)`
  - `enforceWidth` / `enforceHeight` / `String.enforced` →
    `.frame(width:height:)`
  - `clampWidth` / `clampHeight` / `clamp` / `String.clamped` →
    `ViewOutput.clampedWidth(_:)` / `.clampedHeight(_:)` for finished rasters
  - `wrap` / `String.wrapped` → `Text`, which wraps at its allocated width
  - `joinHorizontal` / `joinVertical` → `HStack` / `VStack`
  - `inline` / `String.inlined` → no direct replacement; split the string
  - `Compositor` / `Layer`, `ListRenderer`, `TreeRenderer` → compose with
    views (no direct replacement yet)
  - `visibleWidth` / `height` / `size` / `truncateToVisibleWidth` →
    `StyledText.columnWidth` / `lineCount()`
- **BREAKING** Removed `Progress.viewAs(_:)`; use `viewAsStyledText(_:)`.

## [0.1.0] - Unreleased

First tagged pre-alpha release. The tag is created after this change is merged
and the macOS and Linux CI matrix is green:

```bash
git tag -a v0.1.0 -m "Chai 0.1.0"
git push origin v0.1.0
```

### Added

- MIT license.
- GitHub Actions CI for macOS and Linux with a zero-warning gate and OpenSpec
  validation.
- `CHANGELOG.md` and the release/versioning policy.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) with the prioritized improvement plan.

### Changed

- Migrated the `Progress.viewAs(_:)` test call sites to
  `viewAsStyledText(_:)`; the test target is warning-free.

### Notes

- **Pre-alpha:** the API may change.
- Supported platforms: macOS 14+ (Swift 6.1+) and Linux.
- See [`docs/ROADMAP.md`](docs/ROADMAP.md) for the improvement plan.

[Unreleased]: https://github.com/mjKosmic/chai/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mjKosmic/chai/releases/tag/v0.1.0
