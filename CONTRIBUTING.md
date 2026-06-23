# Contributing

Thanks for contributing! Here's how to get started:

1. Open an issue to discuss the proposed change
2. Create a branch from `main`
3. Implement the change with tests
4. Make sure `bundle exec rake` passes (lint + tests)
5. Open a pull request targeting `main`

---

## Setup

```bash
git clone git@github.com:fluence-eu/filterable-ruby.git
cd filterable-ruby
bin/setup
```

Requires Ruby 3.2+.

## Development

```bash
bundle exec rake        # default task: specs + rubocop
bundle exec rspec       # specs only
bundle exec rubocop     # lint only
bundle exec rubocop -A  # auto-fix linting
bin/console             # interactive prompt
```

The test suite runs against an in-memory SQLite database — nothing to set up.
Coverage is enforced via SimpleCov (`minimum_coverage 90`); skip it locally with
`SKIP_COVERAGE=true bundle exec rspec` when iterating.

---

## Commit Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/).

### Format

```
<type>(<scope>): <description>

[body]

[footer(s)]
```

### Types

| Type       | Description                                                  |
|------------|--------------------------------------------------------------|
| `feat`     | New feature                                                  |
| `fix`      | Bug fix                                                      |
| `docs`     | Documentation only changes                                   |
| `style`    | Formatting changes (whitespace, commas, etc.) — no logic     |
| `refactor` | Code change that neither fixes a bug nor adds a feature      |
| `perf`     | Performance improvement                                      |
| `test`     | Adding or updating tests                                     |
| `build`    | Changes to build system or dependencies                      |
| `ci`       | CI/CD configuration changes                                  |
| `chore`    | Other changes that don't modify source or tests              |
| `revert`   | Revert a previous commit                                     |

### Description

- Use imperative mood ("add", not "adds" or "added")
- No capital letter at the start
- No period at the end
- Maximum 72 characters

### Body (optional)

- Use bullet points with `-` for multiple items
- Explain **why**, not **what** (the diff speaks for itself)

### Breaking Changes

Non-backward-compatible changes must be flagged with:

- A `!` after the type/scope: `feat(sortable)!: change sort param format`
- And/or a `BREAKING CHANGE:` footer in the body

### Examples

```
feat(datable): add `since` bound
```

```
fix(sortable): ignore undeclared attributes instead of raising

- a bogus `filters[sort]` term used to leak an arbitrary column
- whitelist against the declared sortable attributes
```

---

## Branching Model

- **`main`** — default branch. All feature branches are created from here, and all
  PRs target this branch.
- Never push directly to `main` — always create a feature branch and open a PR.

---

## Pull Request Convention

### PR Title

- Same format as commits: `<type>(<scope>): <description>`
- Under 72 characters

### PR Classification

| Level    | Criteria                                                | Description requirements                                            |
|----------|---------------------------------------------------------|--------------------------------------------------------------------|
| Critical | Breaking change, security fix                           | Full description — summary, changes, impact, rollback, how to test |
| Major    | New feature, significant refactor                       | Summary + changes + how to test                                    |
| Minor    | Small bug fix, config tweak, dependency bump            | Summary + changes (1-2 lines each)                                 |
| Trivial  | Documentation, formatting, comment update               | One-line summary is enough                                         |

### PR Description by Level

#### Critical / Major

```markdown
## Summary
<What and why in 2-3 sentences>

## Changes
- <change 1>
- <change 2>

## How to Test
1. <step 1>
2. <step 2>
```

For **Critical** PRs, also add an `## Impact` and a `## Rollback Plan` section.

#### Minor

```markdown
## Summary
<One sentence>

## Changes
- <change 1>
```

#### Trivial

A one-line summary in the PR body is sufficient.

### Rules

- One topic per PR — don't mix unrelated changes
- All tests must pass (`bundle exec rake`)
- New code must include tests
- Never commit secrets or credentials

---

## Code Conventions

- `frozen_string_literal: true` on every Ruby file
- Strings: single quotes (unless interpolation is needed)
- RuboCop: no rule disabling without justification
- YARD-style doc comments on public methods
- Version lives in `lib/filterable/version.rb` — do not bump it except for a release

---

## AI-Assisted Contributions

When using AI tools (Claude, Copilot, etc.) to generate commits or PRs:

- **Classify first** — determine if the change is critical, major, minor, or trivial
- **Focus on the "why"** — the diff already shows the "what"
- **Skip boilerplate** — don't add empty sections or placeholder text

The person opening the PR takes full responsibility for the code. Before submitting:

- [ ] I have read and understood every line of code in this PR
- [ ] I can explain why each change was made
- [ ] I have tested the changes locally

Do **not** add AI co-author lines (`Co-Authored-By`), "Generated with" footers, or
any AI attribution in commits or PR descriptions.

---

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).
