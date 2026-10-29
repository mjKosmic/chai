# Proposal

## Why

`retire-string-layout` removed the only part of Latte that could stand on its
own. What remains — styling values and the declarative containers — depends on
Chai's `View`, `StyledText`, and `Cell` types in every file. The target boundary
no longer separates independent concerns:

- It splits one DSL across two modules: leaves (`Text`, `Spacer`, `Fill`,
  `ViewOutput`) are in Chai, containers (`VStack`, `HStack`, `frame`, padding,
  borders) are in Latte. Chai alone cannot express a stack.
- It forces the engine SPI to be public for a structural reason (calling across
  the target boundary) rather than an extensibility one.
- It duplicates the display-width implementation, and makes the styling bridge
  live in the module above the one that defines the styling values.
- It makes every app that wants a stack import two products.

The package is pre-1.0 (`0.1.0` is unreleased), so folding the remaining code
now costs one import change. Later it would need a deprecation cycle.

## What Changes

- **BREAKING** Remove the `Latte` library product and target. Its surviving code
  moves into `Chai`:
  - `VStack`, `HStack`, `FrameView`, `PaddingView`, `BorderView`, `.beside`,
    `.above` → `Sources/Chai/Layout/`
  - `Border` glyph sets and the `HorizontalAlignment`/`VerticalAlignment` value
    types → `Sources/Chai/Layout/`
  - `Style`, `Color`, `ANSIColor`, `ColorProfile`, `ColorPalette`,
    `ColorUtilities`, and the `Style` → `TextAttributes` bridge →
    `Sources/Chai/Style/`
  - `expandTabs` and `String.tabsExpanded` → `Sources/Chai/Utilities/`
  - Delete Latte's internal `DisplayWidth.swift`; the moved border and tab code
    use Chai's single internal implementation.
- Keep the engine SPI public. Custom containers remain a supported extension
  point; the built-in containers now live in the same module, so public SPI is a
  deliberate choice rather than a workaround.
- Expose two products (`Chai`, `Spices`). Update `Spices`, the GroceryList
  example, and the test targets to depend on `Chai` only.
- Rename the `LatteTests` target to `ChaiViewTests` and retarget its imports at
  `Chai`; `ChaiTests` drops its `Latte` dependency.
- Update documentation to describe two products and the new source layout:
  `README.md`, `ARCHITECTURE.md`, `AGENTS.md`, `CLAUDE.md`,
  `docs/ROADMAP.md`, `CHANGELOG.md`, `openspec/config.yaml`, and the module DocC.

**Non-goals**

- Any layout, rendering, or styling behavior change; the parity corpus
  `expectedRows` must stay identical.
- Internalizing the engine SPI.
- Rewriting Spices components to build bodies from the view tree.
- Adding a `ZStack`/overlay container.
- Changing `Style.render`, `ColorProfile`, raster clamps, or tab expansion.

**Affected products and modules:** Chai (receives the surviving Latte code),
Latte (removed), Spices (imports only), the GroceryList example (imports only),
the test targets, and project documentation.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- None. Module placement is packaging, not behavior. The `view-api` spec already
  describes the composition surface without naming modules, so folding does not
  change any requirement.

## Impact

- **BREAKING** for anyone writing `import Latte`: replace it with
  `import Chai`. Pre-alpha policy applies; no compatibility shim.
- No runtime or rendered behavior change. No spec change; `.openspec.yaml` sets
  `skip_specs: true`.
- Test targets: `LatteTests` is renamed `ChaiViewTests`; `ChaiTests` no longer
  depends on Latte. Test and suite counts are unchanged.
- Dependencies: `Spices` depends on `Chai` only; the example and both test
  targets likewise. The `Latte` product and target are removed.
