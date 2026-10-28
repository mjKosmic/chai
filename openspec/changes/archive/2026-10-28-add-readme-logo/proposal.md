# Proposal

## Why

`README.md` opens with a bare `# Chai` heading and the repository ships no
visual identity, so the project is hard to recognize in a list of repositories,
in link previews, or in the package ecosystem. A small, original mark costs
almost nothing and communicates the two things Chai actually is: a chai (the
name) and a terminal UI (the `>_` prompt).

## What Changes

- Add `docs/assets/logo.svg`: an original, hand-authored SVG mark — a cream
  chai cup on an amber-to-clay rounded tile, with a shell prompt (`>_`) rising
  as steam. It carries its own background, so it reads correctly on both
  GitHub light and dark themes.
- Add `docs/assets/logo.png` (256×256, transparent corners) rendered from the
  SVG, for surfaces that do not render SVG (avatars, package indexes, social
  cards).
- Add a centered 128 px header image to `README.md` with descriptive alt text.
- **Non-goals:** no runtime, renderer, layout, input, or component behavior
  changes; no new dependencies; no changes to `Package.swift`, products, or
  public API; no wordmark, no favicon/bundle-icon wiring, no CI changes.
- **BREAKING:** none.

## Capabilities

### New Capabilities

- None. This is a documentation and asset change with no observable product
  behavior delta, so it sets `skip_specs: true` rather than inventing a
  requirement.

### Modified Capabilities

- None.

## Impact

- New files: `docs/assets/logo.svg`, `docs/assets/logo.png`.
- Modified files: `README.md`.
- Affected products/modules: none — Chai, Latte, Spices, and the GroceryList
  example are untouched.
- Licensing: the mark is original artwork contributed under the existing MIT
  license; no third-party icon set is vendored, so no attribution obligations
  are introduced.
