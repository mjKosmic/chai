# Tasks

## 1. Baseline

- [x] 1.1 Record the baseline: run `swift build --build-tests`, `swift test`, and `npx -y @fission-ai/openspec@1.15.0 validate --all --strict`; capture the test/suite counts and `grep -c "expectedRows:" Tests/ChaiViewTests/LayoutParity/ParityCorpus.swift`. Verification: all commands pass and the counts (expected 992 tests / 98 suites, 45 corpus rows) are recorded in the PR description.

## 2. Make `Color` the authoring color

- [x] 2.1 Add the 16 named ANSI conveniences to `Color` (`.black` … `.brightWhite`) and a `Color.init(_ cellColor: CellColor)` bridge in `Sources/Chai/Style/Color.swift`. Verification: new `Color` tests cover the named colors and the bridge; `swift build` succeeds.
- [x] 2.2 Change `StyledText.fg`/`.bg` (both the `String` and `StyledText` extensions) to accept `Color`, and add a `TextAttributes` convenience initializer that takes `Color?` foreground/background and converts through `Color.cellColor`. Verification: `swift build` succeeds and the existing `.fg(.red)` call sites compile unchanged.
- [x] 2.3 Update any call sites that pass an explicit `CellColor` to `fg`/`bg` (tests and source) to the `Color` value, and run the full suite. Verification: `swift test` passes with the same test count as the baseline.

## 3. Add view styling modifiers

- [x] 3.1 Add `StyledView<Content>` in `Sources/Chai/Style/StyledView.swift`: forwarding measurement, embedding the child at its reported rect clamped to the allocation, and merging the style into every cell in that rect (fill unset foreground/background/hyperlink, union attributes). Verification: `swift build` succeeds.
- [x] 3.2 Add the `View` styling modifiers `.fg(_:)`, `.bg(_:)`, `.bold()`, `.dim()`, `.italic()`, `.underline()`, `.strikethrough()`, and `.styled(_ style: Style)`, each returning a `StyledView`. Verification: `swift build` succeeds.
- [x] 3.3 Add tests for leaf styling, container styling, wrapper styling, inner-wins precedence, outer-fills-unset, attribute accumulation, and background coverage of internal spaces and inter-child gaps. Verification: the new suite passes and `swift test` stays green.
- [x] 3.4 Add tests proving layout invariance: measurement is equal before and after styling, wrapping at a narrow width is unchanged, and a background adds no rows or columns. Verification: the tests pass.

## 4. Parity and structured output

- [x] 4.1 Add a test that inline styling and view modifiers produce identical cells for the same content (`Text("x".fg(.red).bold())` versus `Text("x").fg(.red).bold()`), and that `.styled(Style(...))` matches the equivalent inline chain. Verification: the test passes.
- [x] 4.2 Add a test that embedded styled views contain no escape bytes in any cell, and that `Style.render` still produces ANSI output for out-of-band use. Verification: the test passes.

## 5. Documentation

- [x] 5.1 Update the styling section of `Sources/Chai/Chai.swift` to show the modifier chain and the single color value, and remove the two-vocabulary wording. Verification: the example compiles conceptually against the new API and the module doc names `fg`/`bg`/`bold`/`styled`.
- [x] 5.2 Update `ARCHITECTURE.md` ("Layout & Styling" design notes) with the wrapper model, the merge rule, and the occupied-rect background rule; update `README.md` with a styled-tree example. Verification: `grep` finds the modifier names in both files and no claim that styling is string-only.
- [x] 5.3 Add a **BREAKING** entry to `CHANGELOG.md` for the `fg`/`bg` color parameter change, and list the new modifiers under Added. Verification: the entry names the migration and `git diff --check` passes.

## 6. Integration verification

- [x] 6.1 Run `swift package clean`, `swift build --build-tests 2>&1 | tee /tmp/chai-styling-build.log`, and verify `grep -c "warning:" /tmp/chai-styling-build.log` is 0.
- [x] 6.2 Run `swift test`; verify all tests pass and record the count delta from the baseline (existing tests plus the new styling cases).
- [x] 6.3 Verify `grep -c "expectedRows:" Tests/ChaiViewTests/LayoutParity/ParityCorpus.swift` is 45, proving no layout expectation moved.
- [x] 6.4 Run `npx -y @fission-ai/openspec@1.15.0 validate --all --strict` and `git diff --check`; verify both pass.
- [x] 6.5 Build the example (`swift build --product GroceryList`) and verify it still compiles after the color-parameter change.

## Workflow follow-up

- Push the branch and open a pull request; verify the `macos`, `linux`, and `openspec` jobs pass.
- Archive this change inside the pull request; verify the `view-styling` main spec is created and the change moves under `openspec/changes/archive/`.
- Next ergonomics changes: `component-composition` (Spices exposes view trees where composition matters) and `view-testing` (public harness for embedding and inspecting views).
