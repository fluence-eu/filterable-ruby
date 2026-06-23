# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-06-23

### Added

- Initial extraction from the ledger-back codebase.
- `Filterable::Concern` — the filtering engine: `add_filter` to register filters
  and `filterable(params)` to fold them over a relation.
- `Filterable::Concerns::Datable` — `datable` DSL plus the after/before/since/range
  date filters.
- `Filterable::Concerns::Sortable` — `sortable` DSL plus `+/-` ordering from
  `filters[sort]`.
- `Filterable::Railtie` — auto-includes the engine into `ActiveRecord::Base` via
  `on_load(:active_record)`, so Rails models need no explicit `include`.

### Changed

- Dropped the Zeitwerk dependency in favour of explicit `require_relative`s,
  matching the other Fluence gems and keeping the guarded Railtie require clean.

[Unreleased]: https://github.com/fluence-eu/filterable-ruby/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/fluence-eu/filterable-ruby/releases/tag/v0.2.0
