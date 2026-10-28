# Tasks

## 1. Asset

- [x] 1.1 Add `docs/assets/logo.svg` as a self-contained mark: 128×128 viewBox, embedded gradient, no external references, `<title>` and `role="img"` for accessibility. Verify it parses as XML (`xmllint --noout docs/assets/logo.svg`) and references no `http` URLs other than the SVG namespace.
- [x] 1.2 Render `docs/assets/logo.png` at 256×256 from the SVG and mask the raster's page background to the tile's rounded silhouette so the corners are transparent. Verify with `sips -g pixelWidth -g pixelHeight -g hasAlpha` (256, 256, yes) and visually at 48 px and 256 px.

## 2. README

- [x] 2.1 Add a centered header image to `README.md` referencing `docs/assets/logo.svg` at 128 px with alt text describing the mark. Verify the relative path resolves from the repository root and the rest of the README is unchanged.

## 3. Validation

- [x] 3.1 Run `npx -y @fission-ai/openspec@1.15.0 validate --all --strict` and `git diff --check`; verify both pass.
- [x] 3.2 Confirm no source, test, or manifest files changed (`git diff --stat` touches only `README.md`, `docs/assets/`, and `openspec/`), so the zero-warning and test-suite gates are unaffected.

## Workflow follow-up

- Push the branch and open a pull request; verify the macOS, Linux, and OpenSpec jobs pass.
- Archive this change inside its pull request before merge.
