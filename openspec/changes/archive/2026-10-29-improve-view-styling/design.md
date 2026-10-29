# Design

## Context

See `proposal.md` → Why. Current state relevant to the approach:

- Two color types exist. `Color` has `.ansi(ANSIColor)`, `.extended(UInt8)`,
  `.trueColor`, hex parsing, and downsampling. `CellColor` is the renderer's
  cell-level enum with named cases, palette indices, and RGB. The bridge
  `Color.cellColor` already exists in `Style+TextAttributes.swift`.
- `StyledText.fg`/`.bg` take `CellColor`; `Style.foreground`/`.background` take
  `Color`.
- Styling a subtree has no expression: there is no view-level style modifier.
  The engine has no environment mechanism, and `_embed` has no style parameter.
- `PaddingView` and `BorderView` are the precedent for a wrapper that queries
  its child, picks a rect from the report, embeds the child there, and paints
  only inside it.

## Goals / Non-Goals

**Goals:**

- One color value at authoring call sites.
- Style any subtree, including containers and wrappers.
- Deterministic, documented composition; layout invariance.
- Identical cells from inline styling and modifiers.

**Non-Goals:**

- Changing the renderer, `Cell`, `CellColor`, or the allocation SPI.
- Introducing a style environment or view identity.
- Theme presets, overlays, or component-tree work.

## Decisions

### 1. `Color` is the authoring color; `CellColor` stays cell-level

`Color` is already the richer type (named ANSI, 256, true color, hex,
downsampling) and is what `Style` uses. Making it canonical means adding the 16
named conveniences (`.red`, ...) so existing `.red` call sites keep compiling,
and changing `StyledText.fg`/`.bg` to accept `Color` rather than overloading.
Overloading would make `.red` ambiguous. `CellColor` remains public because
`Cell` and `TextAttributes` expose it, and custom cell-painting views need it;
it is documented as the renderer representation, not the application styling
API. A `Color.init(_ cellColor: CellColor)` bridge keeps low-level code
interoperable.

*Alternative considered:* make `CellColor` canonical. Rejected: it lacks hex
parsing and downsampling, and it leaks the renderer's representation into
application code.

### 2. Styling is a paint-time wrapper, not an engine parameter

`StyledView<Content>` implements `_measure` by forwarding the child and `_embed`
by:

1. querying the child for its report under the assignment,
2. clamping the report to the assignment to get the occupied rect,
3. embedding the child at that rect,
4. merging the requested attributes into every cell in that rect.

The wrapper is local, composes with padding/border/frame, and needs no engine
change. *Alternatives considered:* a style environment (no environment exists;
would add identity-like machinery), and a `_embed` style parameter (touches
every conformer and the renderer for a presentation concern). Both rejected.

### 3. Merge rule: fill unset, accumulate attributes

For each cell in the occupied rect:

- foreground, background, and hyperlink are set only when the cell's value is
  `nil`;
- text attributes are unioned.

Because wrappers nest inside-out, the inner modifier writes first and the outer
modifier sees a non-`nil` value and leaves it. This gives the expected
inheritance rule — the innermost explicit value wins, outer attributes still
accumulate — without tracking a separate style environment.

### 4. Style the occupied rect, including spaces

The occupied rect is the child's report clamped to the allocation, matching the
shrink-wrap behavior of `PaddingView`/`BorderView`. Background is written to
every cell in that rect, so a background fills internal spaces and gaps between
children; foreground and attributes are also written to every cell, which is
visually inert on spaces. Styling stops at the rect boundary, so a style on a
shrink-wrapped child does not paint its parent's empty area.

*Alternative considered:* style only non-space glyphs. Rejected: `Cell` cannot
distinguish a painted space from an unwritten cell, and skipping spaces would
break backgrounds on text containing spaces.

### 5. `Text` has no special case

The modifiers live in a `View` extension, so `Text`, `VStack`, `HStack`,
`FrameView`, `PaddingView`, `BorderView`, `AnyView`, and user-defined views all
get them. No `Text`-specific API is added.

### 6. Keep `Style` and `Style.render`

`Style` remains the declarative style value and gains nothing structural; the
`.styled(_:)` modifier applies `style.textAttributes`. `Style.render` remains
for `Command.println` output. `StyledText.styled(TextAttributes)` stays as the
low-level escape hatch for cell-level styling; the spec's "one color value"
requirement applies to the primary application APIs.

## Risks / Trade-offs

- **A background on a view allocated the full terminal fills that rect.** →
  The wrapper uses the child's *report*, not the assignment, so shrink-wrapped
  views fill only their content; `Fill`/`frame` opt into the larger box. This is
  documented and consistent with the shrink-wrap contract.
- **Nested wrappers cost O(occupied area) each.** → Acceptable at terminal
  sizes; styling is applied once per frame and only on the occupied rect.
- **Changing `StyledText.fg`/`.bg` breaks `CellColor` call sites.** → Marked
  **BREAKING**; the named-color call sites are covered by `Color`'s new
  conveniences.
- **A style modifier silently has no effect on a child that paints outside its
  report.** → The hard-box contract already clips to the child's rect; the
  wrapper styles exactly that rect, so no extra clipping rule is introduced.
- **Color name collisions with `CellColor`.** → The parameter type selects
  `Color`; `.red` resolves unambiguously. `CellColor` call sites become
  `Color(.red)` or `.red` after migration.

## Migration Plan

| Before | After |
|---|---|
| `"x".fg(.red)` where `.red` is `CellColor` | `"x".fg(.red)` where `.red` is `Color` |
| `"x".fg(CellColor.red)` | `"x".fg(.red)` or `"x".fg(Color(.red))` |
| `Text("x".fg(.red))` | unchanged, or `Text("x").fg(.red)` |
| `Text(Style().foreground(.ansi(.red)).styledText("x"))` | `Text("x").styled(Style().foreground(.red))` |

Rollback is a revert; no persistent state.

## Open Questions

None.
