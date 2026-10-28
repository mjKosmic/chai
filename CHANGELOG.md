# Changelog

All notable changes to Chai are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Pre-1.0 releases may contain breaking changes; the migration history lives in
[`docs/history/VIEW-LAYER-MIGRATION-LOG.md`](docs/history/VIEW-LAYER-MIGRATION-LOG.md).

## [Unreleased]

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
