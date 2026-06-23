# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial extraction from the ledger-back codebase.
- `Filterable::Concern` — the filtering engine: `add_filter` to register filters
  and `filterable(params)` to fold them over a relation.
- `Filterable::Concerns::Datable` — `datable` DSL plus the after/before/since/range
  date filters.
- `Filterable::Concerns::Sortable` — `sortable` DSL plus `+/-` ordering from
  `filters[sort]`.

[Unreleased]: https://github.com/fluence-eu/filterable-ruby/commits/main
