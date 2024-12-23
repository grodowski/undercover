# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

# [0.6.3] - 2024-12-23

### Fixed
- Fix false positives with empty blocks/methods on a single line ([#216](https://github.com/grodowski/undercover/issues/216)) by [@splattael](https://github.com/splattael).
- Updated list of default excluded directories (added `db/` and `config/`)

# [0.6.0] - 2024-12-12
### Added
- Add support for including and exluding files by glob patterns, supplied through CLI args and the configuration file (#146)

### Fixed
- Files that were changed but don't appear in the coverage report at all will now be reported as uncovered, as expected.
- Fixed an issue where top-level methods were not being considered [#135](https://github.com/grodowski/undercover/issues/135). This was caused by a bug in the tree traversal logic.
- Fixed a bug where `--compare` didn't work with grafted commits as there was no merge base available ([#175](https://github.com/grodowski/undercover/issues/175)). Now it's possible to pass a graft commit as `--compare` which enables `undercover` to work with shallow clones.

# [0.5.0] - 2024-01-09
### Changed
- Drop ruby 2.x support, require ruby 3.x in gemspec
- Dev dependency updates

# [0.4.7] - 2024-01-08
### Fixed
- [Update of one-line block is ignored](https://github.com/grodowski/undercover/pull/207) by [@lizhangyuh](https://github.com/lizhangyuh)

# [0.4.6] - 2023-04-21
### Added
- #total_coverage and #total_branch_coverage in the LcovParser

### Changed
- Drop support for ruby < 2.7
- Test coverage with both local `undercover` and Undercover GitHub App for demo purposes

# [0.4.5] - 2022-07-28
### Changed
- Update `rugged` dependency to `< 1.6`

# [0.4.4] - 2021-11-29
### Changed
- Dependency updates

# [0.4.3] - 2021-03-16
### Fixed
- Branch coverage without line coverage marked as uncovered - fix by @GCorbel

# [0.4.1] - 2021-03-11
### Fixed
- Fix zero-division edge case resulting in NaN from Result#coverage_f

# [0.4.0] - 2021-02-06
### Added
- [Minimal implementation of branch coverage in LCOV parser](https://github.com/grodowski/undercover/pull/112) by [@magneland](https://github.com/magneland)
- Branch coverage output support in Undercover::Formatter
### Changed
- Min Ruby requirement bumped to 2.5.0
- Dependency updates: Rubocop 1.0 and Rugged 1.1.0


## [0.3.4] - 2020-04-05
### Changed
- Updated parsing performance by scoping `all_results` to git diff
- Dependecy updates

## [0.3.3] - 2019-12-29
### Fixed
- `.gemspec` requires `imagen >= 0.1.8` to address compatibility issues

## [0.3.2] - 2019-05-08
### Fixed
- LCOV parser fix for incorrect file path handling by @RepoCorp

## [0.3.1] - 2019-03-19
### Changed
- Compatibility with `pronto > 0.9` and `rainbow > 2.1`

## [0.3.0] - 2019-01-05
### Added
- Support for `.undercover` config file by @cgeorgii

## [0.2.3] - 2018-12-26
### Fixed
- `--ruby-syntax` typo fix by @cgeorgii

### Changed
- `travis.yml` update by @Bajena

## [0.2.2] - 2018-12-16
### Fixed
- Change stale_coverage error into a warning

## [0.2.1] - 2018-09-26
### Fixed
- Bug in mapping changed lines to coverage results

## [0.2.0] - 2018-08-19
### Added
- This `CHANGELOG.md`
- Ruby syntax version customisable with `-r` or `--ruby-syntax`

### Fixed
- Relative and absolute project path support
- typo in stale coverage warning message by @ilyakorol

## [0.1.7] - 2018-08-03
### Changed
- Readme updates by @westonganger.

### Fixed
- Handled invalid UTF-8 encoding errors from `parser`

## [0.1.6] - 2018-07-10
### Fixed
- Updated `imagen` to `0.1.3` which avoids a broken release of `parser`

## [0.1.5] - 2018-06-25
### Changed
- Avoided conflicts between `rainbow` and `pronto` versions for use in upcoming `pronto-undercover` gem

## [0.1.4] - 2018-05-20
### Fixed
- Quick fix 🤷‍♂️

## [0.1.3] - 2018-05-20
### Added
- `imagen` version bump adding block syntax support

## [0.1.2] - 2018-05-18
### Fixed
- `--version` cli option fix

## [0.1.1] - 2018-05-17
### Fixed
- CLI exit codes on success error

## [0.1.0] - 2018-05-10
### Added
- First release of `undercover` 🎉

[Unreleased]: https://github.com/grodowski/undercover/compare/v0.6.3...HEAD
[0.6.3]:https://github.com/grodowski/undercover/compare/v0.6.3...v0.6.0
[0.6.0]: https://github.com/grodowski/undercover/compare/v0.6.0...v0.5.0
[0.5.0]: https://github.com/grodowski/undercover/compare/v0.4.7...v0.5.0
[0.4.7]: https://github.com/grodowski/undercover/compare/v0.4.6...v0.4.7
[0.4.6]: https://github.com/grodowski/undercover/compare/v0.4.5...v0.4.6
[0.4.5]: https://github.com/grodowski/undercover/compare/v0.4.4...v0.4.5
[0.4.4]: https://github.com/grodowski/undercover/compare/v0.4.3...v0.4.4
[0.4.3]: https://github.com/grodowski/undercover/compare/v0.4.1...v0.4.3
[0.4.1]: https://github.com/grodowski/undercover/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/grodowski/undercover/compare/v0.3.4...v0.4.0
[0.3.4]: https://github.com/grodowski/undercover/compare/v0.3.3...v0.3.4
[0.3.3]: https://github.com/grodowski/undercover/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/grodowski/undercover/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/grodowski/undercover/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/grodowski/undercover/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/grodowski/undercover/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/grodowski/undercover/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/grodowski/undercover/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/grodowski/undercover/compare/v0.1.7...v0.2.0
[0.1.7]: https://github.com/grodowski/undercover/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/grodowski/undercover/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/grodowski/undercover/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/grodowski/undercover/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/grodowski/undercover/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/grodowski/undercover/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/grodowski/undercover/compare/v0.1.0...v0.1.1
