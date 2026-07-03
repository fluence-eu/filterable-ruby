# Changelog

All notable changes to this project will be documented in this file.
## [1.0.0] - 2026-07-03

### Added

- feat(matchable): let the request override case sensitivity
- feat(matchable): add whitelisted partial matching
- feat(concern): hand a call context to context-aware filters
- feat(attachable): expand the image shortcut in the type key
- feat(attachable): add ActiveStorage pre-filtering sugar
- feat(target): cross polymorphic belongs_to with a declared concrete type
- feat(target): filter through declared association paths
- feat(concern): add declarative default filters
- feat(togglable): toggle on a bare key
- feat(scopable): delegate filters to declared model scopes
- feat(concern): add applied_filters introspection
- feat(rangeable): add whitelisted numeric bound filtering
- feat(validator): add declarations validator for specs
- feat(equatable): add whitelisted equality filtering

### Build

- build(deps): add activestorage to the test harness

### CI

- ci: align CI with ci-workflows canonical setup (per README)

### Documentation

- docs(yard): hide method source from the published documentation
- docs(readme): document the matchable DSL
- docs(readme): document the filter call context
- docs(readme): document the image type shortcut
- docs(readme): document the attachable DSL
- docs(readme): document ActiveStorage attachment paths
- docs(readme): document association targets
- docs(readme): document default filters
- docs(validator): complete the initialize YARD doc
- docs(readme): document the scopable and togglable DSLs
- docs(readme): document applied_filters introspection
- docs(readme): document the rangeable DSL
- docs(readme): document the declarations validator
- docs(readme): document the equatable DSL

### Fixed

- fix(datable): ignore non-hash bounds instead of raising
- fix(concerns): inherit datable/sortable declarations in subclasses

### Other

- chore(gemspec): credit Jonathan PHILIPPE as author
- chore(deps): manage dev dependencies via bundle add

### Refactored

- refactor(attachable): derive blob associations from the reflection macro
- refactor(attachable): resolve attachments through the reflection registry
- refactor(equatable): extract value normalization into its own module
- refactor(filters): share the skip decision between call and applied

### Style

- style(concern): keep the class_methods DSL, scope BlockLength instead

### Tests

- test(activestorage): prove association targets through attachments

## [0.1.0] - 2026-06-23

### Added

- feat(railtie): auto-include the engine into ActiveRecord

### CI

- ci: add the Fluence gem CI workflow stack

### Other

- chore(deps): bump actions/checkout from 6 to 7
- chore(release): bump version to 0.2.0
- chore: initial commit — extract filterable from ledger-back

### Reverted

- revert: roll back version bump, return to 0.1.0

