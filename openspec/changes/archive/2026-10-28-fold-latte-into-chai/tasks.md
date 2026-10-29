# Tasks

## 1. Baseline

- [x] 1.1 Record the baseline: run `swift build --build-tests`, `swift test`, and `npx -y @fission-ai/openspec@1.15.0 validate --all --strict`; capture the test/suite counts and `grep -c "expectedRows:" Tests/LatteTests/LayoutParity/ParityCorpus.swift`. Verification: all three commands pass and the counts (expected 992 tests / 98 suites, 45 corpus rows) are recorded in the PR description.

## 2. Move the layout layer into Chai

- [x] 2.1 Move `Sources/Latte/Layout/{Stacks,Frame,PaddingView,BorderView,CompositionWrappers,Alignment}.swift` and `Sources/Latte/Borders/Border.swift` into `Sources/Chai/Layout/` with `git mv`. Verification: the files exist under `Sources/Chai/Layout/` and `Sources/Latte/Layout` and `Sources/Latte/Borders` are empty.
- [x] 2.2 Remove `import Chai` from the six moved files that declare it (`Stacks`, `Frame`, `PaddingView`, `BorderView`, `CompositionWrappers`; `Alignment` and `Border` never imported it) and verify `swift build` succeeds.

## 3. Move styling and text utilities into Chai

- [x] 3.1 Move `Sources/Latte/Style/*.swift` into `Sources/Chai/Style/` with `git mv`, including `Style+TextAttributes.swift`; remove its `import Chai`. Verification: `swift build` succeeds.
- [x] 3.2 Move `Sources/Latte/Utilities/TabExpansion.swift` to `Sources/Chai/Utilities/`, delete `Sources/Latte/Measurement/DisplayWidth.swift`, and confirm `BorderView` and `TabExpansion` resolve `displayWidth` from `Sources/Chai/Renderer/DisplayWidth.swift`. Verification: `swift build` succeeds and `find Sources/Latte` is empty.
- [x] 3.3 Delete `Sources/Latte/Latte.swift` after folding its surviving layout/styling/border/tab documentation into `Sources/Chai/Chai.swift`. Verification: `swift build` succeeds, `Sources/Latte` no longer exists, and `grep -n "VStack\|Style\|expandTabs" Sources/Chai/Chai.swift` reports the folded sections.

## 4. Update the package and consumers

- [x] 4.1 Update `Package.swift`: remove the `Latte` product and target, set `Spices` dependencies to `["Chai"]`, set `ChaiTests` to `["Chai"]`, rename the `LatteTests` test target to `ChaiViewTests` with `path: "Tests/ChaiViewTests"`, and set `GroceryList` dependencies to `["Chai", "Spices"]`. Verification: `grep -c "Latte" Package.swift` is 0 after the renames.
- [x] 4.2 Rename `Tests/LatteTests` to `Tests/ChaiViewTests` with `git mv`. Replace `@testable import Latte` with `@testable import Chai`; for files importing both `Chai` and `Latte`, delete the Latte line. Verification: `swift build --build-tests` succeeds and `grep -rn "import Latte" Tests/ChaiViewTests` is empty.
- [x] 4.3 Update `Tests/ChaiTests`: remove the `import Latte` lines from `TextWrappingTests`, `MinimumSizeTests`, `RendererEnginePathTests`, `LayoutEngineTests`, and `AnyViewTests`; update the `RectEchoView` "cannot see this file" comment to name `ChaiViewTests`. Verification: `swift build --build-tests` succeeds and `grep -rn "import Latte" Tests/ChaiTests` is empty.
- [x] 4.4 Update `Sources/Spices`: remove `import Latte` from the 13 component files, adding `import Chai` where the file does not already declare it. Update `Spices.swift` docs so styling and modifiers are described as part of Chai. Verification: `swift build` succeeds, `swift test --filter SpicesTests` passes, and `grep -rn "import Latte" Sources/Spices` is empty.
- [x] 4.5 Remove `import Latte` from `Examples/GroceryList/Sources/main.swift`. Verification: `swift build --product GroceryList` succeeds.
- [x] 4.6 Update remaining Latte references in source and test comments: `Sources/Chai/Core/ViewOutput.swift` ("from Latte"), `Sources/Spices/List/FilterDelegate.swift`, and the `LayoutEngineTests`/`RectEchoView` comments. Verification: `grep -rn "Latte" Sources Tests Examples` reports no module, product, path, or target references (changelog/history excluded).

## 5. Documentation

- [x] 5.1 Update `README.md`: modules table shows `Chai` (runtime, view tree, layout, styling) and `Spices`; remove the `Latte` product from the install block and any "import Latte" examples. Verification: `grep -n "Latte" README.md` is empty.
- [x] 5.2 Rewrite the relevant parts of `ARCHITECTURE.md`: "three libraries" to two, remove the Latte module-table row, replace the "Latte — Layout & Styling Library" section with a "Layout & Styling" section under Chai, update the engine's `Files:` paths and the SPI paragraph to say the built-in containers live in Chai, rename `LatteTests` to `ChaiViewTests` in the testing table, and update the package tree. Verification: `grep -n "Sources/Latte\|LatteTests\|Latte —\|three libraries" ARCHITECTURE.md` is empty and the test count still reads 992 tests / 98 suites.
- [x] 5.3 Update `AGENTS.md` and `CLAUDE.md`: repository layout lists `Sources/Chai/Layout` and `Sources/Chai/Style`, drops `Sources/Latte`, and names `Tests/ChaiViewTests`; the engine-seam paragraph says the containers and the SPI share a module while the SPI remains public for custom containers. Verification: `grep -n "Sources/Latte\|LatteTests" AGENTS.md CLAUDE.md` is empty.
- [x] 5.4 Update `docs/ROADMAP.md` (remove "mirrors the Latte model" and any remaining Latte product references), `openspec/config.yaml` (two products; Chai includes styling and the declarative containers), and `CHANGELOG.md` (a **BREAKING** entry with the `import Latte` → `import Chai` migration). Verification: `grep -rn "Latte" docs/ROADMAP.md openspec/config.yaml` reports no live product references and the changelog entry names the import change.

## 6. Integration verification

- [x] 6.1 Run `swift package clean`, `swift build --build-tests 2>&1 | tee /tmp/chai-fold-build.log`, and verify `grep -c "warning:" /tmp/chai-fold-build.log` is 0.
- [x] 6.2 Run `swift test` and verify 992 tests in 98 suites pass, matching the baseline.
- [x] 6.3 Verify `grep -c "expectedRows:" Tests/ChaiViewTests/LayoutParity/ParityCorpus.swift` is 45, proving no layout expectation moved.
- [x] 6.4 Run `npx -y @fission-ai/openspec@1.15.0 validate --all --strict` and `git diff --check`; verify both pass.
- [x] 6.5 Verify the package shape: `swift package describe` lists `Chai` and `Spices` with no `Latte` product or target (SwiftPM also exposes the `GroceryList` executable as a product), and `swift build --product GroceryList` succeeds.
- [x] 6.6 Verify no `Latte` target, product, module, or path remains: `grep -rn "import Latte" Sources Tests Examples` is empty and `find Sources Tests -name '*Latte*'` is empty.

## Workflow follow-up

- Push the branch and open a pull request; verify the `macos`, `linux`, and `openspec` jobs pass.
- Archive this change inside the pull request; verify the change moves under `openspec/changes/archive/` and no active change remains.
- After merge, the module consolidation is complete; the next candidate is the 1.0 API audit (roadmap R19).
