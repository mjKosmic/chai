# Proposal

## Why

The post-consolidation review ranked styling as the top authoring friction:

- **Two color values at call sites.** `Style` and its modifiers take `Color`
  (`.ansi(.red)`), while `StyledText.fg`/`.bg` take `CellColor` (`.red`). Users
  must remember which type each API expects and convert between them.
- **Two styling APIs.** Text can be styled inline (`"x".fg(.red).bold()`) or
  through a style value (`Style().foreground(.ansi(.red)).styledText("x")`).
  They produce the same cells but read as unrelated systems.
- **No styling on views.** `Text("x").bold()` does not compile. Styling is a
  string operation, so a stack, a bordered block, or a whole subtree cannot be
  styled without styling every leaf first.
- **No subtree styling.** Applying a foreground or background to a composed
  view has no expression at all.

This change makes styling one vocabulary across strings and views, and lets a
style apply to any view subtree. Layout and rendering behavior stay unchanged.

## What Changes

- **BREAKING** `Color` becomes the single public color value at styling call
  sites. `StyledText.fg`/`.bg` and the new view modifiers accept `Color`;
  `Color` gains the 16 named ANSI conveniences (`.red`, `.green`, ...) so
  existing `.red` call sites keep working. `CellColor` stays public as the
  renderer's cell-level representation but is no longer required in
  application styling code.
- Add view styling modifiers, available on every `View`:
  `.fg(_:)`, `.bg(_:)`, `.bold()`, `.dim()`, `.italic()`, `.underline()`,
  `.strikethrough()`, and `.styled(_:)` (a `Style`).
- Define composition: a style modifier applies to the glyphs in the view's
  occupied rect. Outer modifiers fill only the properties the inner result left
  unset, so the innermost value wins and attributes accumulate. Styling never
  changes measurement, wrapping, or the allocated rect.
- `Text` keeps its value semantics and gains the modifiers through the shared
  `View` extension; there is no special case for text.
- Keep `Style.render(_:profile:)` and `ColorProfile` for output written outside
  the live view (`Command.println`); view styling never emits ANSI bytes into
  the cell buffer.
- Update the module documentation, `ARCHITECTURE.md`, `README.md`, and
  `CHANGELOG.md`.

**Non-goals**

- Spices component trees (`component-composition`, a follow-up change).
- A public view test harness (`view-testing`, a follow-up change).
- Overlay/`ZStack` containers (roadmap R15).
- Theme/palette presets (the remaining part of roadmap R14).
- Release-safe rejection of ANSI strings passed to `ViewOutput`.
- Any layout, measurement, renderer, input, or terminal behavior change.

**Affected products and modules:** Chai (styling API, new view wrapper, tests,
documentation), Spices (only call sites that use the changed color type), and
the GroceryList example (documentation/example styling).

## Capabilities

### New Capabilities

- `view-styling`: the public styling surface for views and styled text — one
  color value, style modifiers on any view subtree, composition precedence,
  and the layout-invariance and structured-output guarantees.

### Modified Capabilities

- None. `view-api` remains true: views still compose through one tree, and
  styled content still carries structured attributes.

## Impact

- **BREAKING** for call sites that pass a `CellColor` to `StyledText.fg`/`.bg`;
  the parameter becomes `Color` and the named colors continue to work. Pre-alpha
  policy applies.
- New public modifiers on every view; no existing view changes behavior when
  unstyled.
- No change to the parity corpus (`expectedRows`) or to test/suite counts
  beyond the new cases.
