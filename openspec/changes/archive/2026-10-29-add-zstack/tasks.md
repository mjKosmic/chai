# Tasks

## 1. Combined alignment value

- [x] 1.1 Add the combined `Alignment` struct (horizontal + vertical, centered default, named presets, custom fractions) to `Sources/Chai/Layout/Alignment.swift`; verify it builds with `swift build`.
- [x] 1.2 Add `AlignmentTests` covering the default center, every preset's horizontal/vertical pair, and custom fractions; verify with `swift test --filter AlignmentTests`.

## 2. ZStack container and engine

- [x] 2.1 Add `ZStack<Content: View>` with `init(alignment:content:)` to `Sources/Chai/Layout/Stacks.swift`; verify it builds with `swift build`.
- [x] 2.2 Implement the shared allocation shape (query both axes, occupied = max child width/height, no flexibility distribution) and `_measure`; verify `ZStackEngineTests` measurement cases pass.
- [x] 2.3 Implement `_embed`: align each child independently within the occupied box clamped to the assigned rect, intersect with the rect, and embed via `buffer.embed`; verify `ZStackEngineTests` render/alignment cases pass.
- [x] 2.4 Add `ZStackTests` covering declaration-order overlay, shrink-wrap, `Fill`, inert flexible `Spacer`, clipping, empty children, nested stacks, CJK width, and a `RectEchoView` child observing its allocated rect; verify with `swift test --filter ZStack`.
- [x] 2.5 Add `ZStack` cases to `Tests/ChaiViewTests/LayoutParity/ParityCorpus.swift` (overlay order, corner alignment, shrink-wrap, Fill, nested in a stack) and verify `ParityEngineTests` passes.

## 3. Public documentation

- [x] 3.1 Update the container table and overview in `Sources/Chai/Chai.swift` to include `ZStack` and the combined alignment value; verify with `swift build` (DocC compiles).
- [x] 3.2 Update the `README.md` layout example/summary and the `ARCHITECTURE.md` layout module table and design notes with `ZStack` overlay semantics; verify the described example compiles as written.
- [x] 3.3 Update `docs/ROADMAP.md` R15 to record `ZStack` as delivered and leave Toast/Modal as remaining scope; verify no other roadmap item claims it is still missing.

## 4. Integration verification

- [x] 4.1 Run `swift build && swift test` and confirm zero warnings and all suites pass, including the parity corpus.
- [x] 4.2 Run `npx -y @fission-ai/openspec@1.15.0 validate add-zstack --strict` and confirm it passes.

## 5. Review follow-ups

- [x] 5.1 Document the embed-time re-query semantics in `design.md` and `ZStack` DocC, and add the nested-flex test; verify it passes in `swift test --filter ZStack`.
- [x] 5.2 Document background ordering in `README.md`, `design.md`, and `ZStack` DocC, and add tests for both paint orders; verify with `swift test --filter ZStack`.
- [x] 5.3 Add the missing edge-case coverage: custom fractional placement, odd vertical shortage, `.zero` and zero-size rects, height clipping, modifier composition, alt-screen rendering, and a rogue painter; verify with `swift test --filter ZStack` and `swift test --filter RendererEnginePathTests`.
- [x] 5.4 Strengthen the height-query and non-stretch tests so they cannot pass for the wrong reason; verify with `swift test --filter ZStack`.
- [x] 5.5 Deduplicate `ZStackTests` and `ZStackEngineTests`, keeping public-surface behavior in `ZStackTests` and measure/embed assertions in `ZStackEngineTests`; verify with `swift test --filter ZStack`.
- [x] 5.6 Add the `CHANGELOG.md` entry and align the remaining doc nits (`ARCHITECTURE.md`, `docs/ROADMAP.md`, `Alignment.swift` file doc, `AlignmentTests`); verify with `swift build`.
- [x] 5.7 Re-run `swift build && swift test` and `npx -y @fission-ai/openspec@1.15.0 validate add-zstack --strict`.

## Workflow follow-up

- Archive the change after review and validation, inside the same pull request.
- Confirm the delta specs merged into `openspec/specs/layout-engine/spec.md` and `openspec/specs/view-api/spec.md`.
