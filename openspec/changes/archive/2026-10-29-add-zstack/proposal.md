# Proposal

## Why

Chai can arrange children in one dimension (`VStack`, `HStack`) and can position
a single child inside a box (`frame`), but it has no container for stacking
children on top of one another. Terminal UIs routinely need that: overlays,
badges, centered dialogs over a background, and layered decorations. Without a
`ZStack`, users must reach for custom containers or pre-rendered rasters.

## What Changes

- Add a `ZStack` container that overlays its children in declaration order,
  painting later children over earlier ones.
- Add a combined `Alignment` value (horizontal + vertical) with presets such as
  `.topLeft`, `.center`, and `.bottomRight`, used to position every child inside
  the stack's occupied box.
- `ZStack` shrink-wraps to the largest child on both axes, matching SwiftUI and
  the stacks' cross-axis behavior. A `Fill` child still claims the assigned
  space because it reports the query context.
- Children are measured with the parent's width and height query context and are
  allocated rects clamped to the stack's occupied box and the stack's own rect,
  so the existing hard-box clipping applies unchanged.
- Update the public container documentation, `ARCHITECTURE.md`, and the parity
  corpus.

### Non-goals

- No view identity or per-view diffing; z-order is declaration order only.
- No z-index or explicit ordering parameter.
- No background/overlay modifiers, opacity, or blending.
- No flexible leftover distribution inside `ZStack`: `Spacer()` remains inert
  there, as it is outside a main-axis stack.
- No changes to Spices components or the GroceryList example.
- No source-breaking changes; this is an additive API.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `layout-engine`: adds overlay allocation semantics for a `ZStack` container —
  measuring against both axes, shrink-wrapping to the largest child, aligning
  each child within the occupied box, and painting in declaration order.
- `view-api`: adds `ZStack` and the combined `Alignment` value to the public
  composition surface.

## Impact

- **Chai**: new `ZStack` container and `Alignment` value in `Sources/Chai/Layout/`;
  public docs in `Sources/Chai/Chai.swift`; design of record in `ARCHITECTURE.md`.
- **Tests**: new engine and allocation tests plus `ZStack` cases in the layout
  parity corpus.
- **Spices / examples**: unaffected.
- **Dependencies / platform**: none; Swift stdlib only, same platform support.
