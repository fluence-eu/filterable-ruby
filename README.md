# filterable

Declarative, **whitelisted** query filtering and ordering for ActiveRecord.

A model declares which columns are *datable* and *sortable*. `filterable(params)`
then folds a chain of small, composable filters over the relation, reading from
nested request params and touching **only** the columns the model explicitly
exposed. An unknown attribute, a malformed date, or an undeclared sort term
narrows nothing — it never raises and never leaks an arbitrary column into the
query.

Requires **Ruby ≥ 3.2** and **ActiveRecord ≥ 7.1**. No dependency on ActionPack:
`ActionController::Parameters` are supported by duck-typing (`to_unsafe_h`).

---

## Installation

The gem is published to the Fluence GitHub Packages registry:

```ruby
# Gemfile
source 'https://rubygems.pkg.github.com/fluence-eu' do
  gem 'filterable'
end
```

```bash
bundle install
```

---

## Usage

Include the engine and the concerns you need, then declare your columns:

```ruby
class MovementDetail < ApplicationRecord
  include Filterable::Concern
  include Filterable::Concerns::Datable
  include Filterable::Concerns::Sortable

  datable  :value_date, :booking_date
  sortable :value_date, :gross_amount_cents
end
```

> **Include order matters.** `Filterable::Concern` provides `add_filter`, which
> the `Datable`/`Sortable` concerns call at include time — so it must come first.

From a controller, hand the request params straight in:

```ruby
def index
  @details = MovementDetail.filterable(params)
end
```

`filterable` reads from `params[:filters]` and returns an ordinary relation, so
it chains with everything else (pagination, scopes, `includes`, …):

```ruby
MovementDetail.where(account: account).filterable(params).page(2)
```

### Date filters (`Datable`)

Each declared datable attribute accepts these nested keys under `filters[<attribute>]`:

| Key            | Meaning                                  | SQL          |
|----------------|------------------------------------------|--------------|
| `after`        | strictly after the bound                 | `> value`    |
| `before`       | strictly before the bound                | `< value`    |
| `since`        | on or before the bound (inclusive)       | `<= value`   |
| `from` + `to`  | inclusive range (both required)          | `BETWEEN`    |

```ruby
MovementDetail.filterable(
  filters: { value_date: { after: '2026-01-15', before: '2026-03-01' } }
)
```

Unparseable values are dropped silently (the filter is a no-op), so a bad query
param can never raise.

### Ordering (`Sortable`)

`filters[sort]` is a comma-separated list of declared attributes, each optionally
prefixed with `+` (ascending, the default) or `-` (descending):

```ruby
MovementDetail.filterable(filters: { sort: '-value_date,+gross_amount_cents' })
```

Undeclared attributes are ignored.

### Public names vs. DB columns

Both DSLs accept a hash to expose a public name that differs from the column:

```ruby
datable  date:   :value_date
sortable amount: :gross_amount_cents

# filters[date][after] / filters[sort]=-amount
```

### Custom filters

`Filterable::Concern` is the whole engine. Register any object responding to
`call(filters_params, scope)`, or a block, and it joins the fold:

```ruby
class MovementDetail < ApplicationRecord
  include Filterable::Concern

  add_filter do |filters, scope|
    scope.where(reference: filters[:reference]) if filters[:reference]
  end
end
```

A filter returning `nil` leaves the scope untouched, so guard clauses are safe.

---

## How it works

- `Filterable::Concern` keeps a per-class list of filters (cloned down the
  inheritance chain) and `filterable` reduces the relation through them.
- `Filterable::Concerns::Datable` / `Sortable` are thin `ActiveSupport::Concern`
  mixins: they register the concrete filters and add the `datable` / `sortable`
  declaration DSL on top of the engine.
- The concrete date filters live under `Filterable::Datable::{After,Before,Range,Since}`
  and the ordering filter is `Filterable::Sortable`.

---

## Development

```bash
bin/setup            # install dependencies
bundle exec rake     # specs + rubocop (the default task)
bundle exec rspec    # specs only
bundle exec rubocop  # lint only
bin/console          # interactive prompt
```

The suite runs against an in-memory SQLite database (see `spec/spec_helper.rb`),
so there is nothing to set up.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports and pull requests are welcome
on the [GitHub repository](https://github.com/fluence-eu/filterable-ruby).

## License

Released under the [MIT License](LICENSE).
