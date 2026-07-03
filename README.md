# filterable

Declarative, **whitelisted** query filtering and ordering for ActiveRecord.

A model declares which columns are *datable*, *sortable*, *equatable* and
*rangeable*, and which scopes are *scopable* or *togglable*. `filterable(params)`
then folds a chain of small, composable filters over the relation, reading from
nested request params and touching **only** the columns and scopes the model
explicitly exposed. An unknown attribute, a malformed date, or an undeclared
sort term narrows nothing — it never raises and never leaks an arbitrary column
into the query.

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

In a Rails application a `Railtie` auto-includes the engine into every model, so
a model just declares its whitelisted columns:

```ruby
class MovementDetail < ApplicationRecord
  scope :priced,       -> { where.not(gross_amount_cents: nil) }
  scope :cheaper_than, ->(cents) { where(gross_amount_cents: ...cents) }

  datable   :value_date, :booking_date
  sortable  :value_date, :gross_amount_cents
  equatable :reference
  rangeable :gross_amount_cents
  scopable  :cheaper_than
  togglable :priced
end
```

`filterable` is then available on every model; one that declares nothing simply
returns `all`. See [Rails integration](#rails-integration) for what the Railtie
wires, and [Outside Rails](#outside-rails) to opt in manually.

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

### Equality filters (`Equatable`)

Each declared equatable attribute reads `filters[<attribute>]` directly: a
scalar compares with `=`, an array of scalars with `IN`:

```ruby
MovementDetail.filterable(filters: { reference: 'INV-1' })
MovementDetail.filterable(filters: { reference: %w[INV-1 REF-2] })
```

Blank values and non-scalar values (e.g. a hash injected through the query
string) are dropped silently, so an empty form field or a malformed param
narrows nothing.

### Numeric bounds (`Rangeable`)

Each declared rangeable attribute accepts these nested keys under
`filters[<attribute>]`, both inclusive:

| Key           | Meaning                       | SQL          |
|---------------|-------------------------------|--------------|
| `min`         | at or above the bound         | `>= value`   |
| `max`         | at or below the bound         | `<= value`   |
| `min` + `max` | inclusive range               | `BETWEEN`    |

```ruby
MovementDetail.filterable(filters: { gross_amount_cents: { min: 100, max: 250 } })
```

Integer strings are read in base ten, decimals fall back to `Float`;
unparseable or blank bounds are dropped silently. A column may be both
`equatable` and `rangeable`: a scalar value filters by equality, a `min`/`max`
hash by range.

### Scope filters (`Scopable` / `Togglable`)

Existing model scopes can be exposed as filters — the scope name is fixed at
declaration time, never derived from the params:

```ruby
scopable  :cheaper_than   # filters[cheaper_than]=250      → .cheaper_than(250)
togglable :priced         # ?filters[priced] or =true / =1 → .priced
```

A `scopable` scope receives the normalized value (blank or non-scalar values
are dropped). A `togglable` scope takes no argument and toggles on a bare key
(`?filters[priced]`, `filters[priced]=`) or a strict true value (`true`,
`'true'`, `1`, `'1'`); an explicit false value — `'false'`, `'0'`, what Rails'
`check_box` hidden field submits — or an arbitrary string narrows nothing.
A declared name whose scope does not exist, or a scope not returning a
relation, narrows nothing either — the [declarations validator](#validating-declarations)
reports the former.

### Ordering (`Sortable`)

`filters[sort]` is a comma-separated list of declared attributes, each optionally
prefixed with `+` (ascending, the default) or `-` (descending):

```ruby
MovementDetail.filterable(filters: { sort: '-value_date,+gross_amount_cents' })
```

Undeclared attributes are ignored.

### Public names vs. DB columns

All the DSLs accept a hash to expose a public name that differs from the column
or scope:

```ruby
datable   date:      :value_date
sortable  amount:    :gross_amount_cents
equatable ref:       :reference
rangeable amount:    :gross_amount_cents
scopable  max_price: :cheaper_than

# filters[date][after] / filters[sort]=-amount / filters[ref] / filters[amount][min] / filters[max_price]
```

### Default filters

A model can declare default filter params, applied whenever the request does
not carry the key:

```ruby
class MovementDetail < ApplicationRecord
  default_filters sort: '-value_date', value_date: -> { { since: Date.current } }
end
```

Defaults are merged under the request's `filters`: an absent key falls back to
its default, and a present key — even blank — suppresses it. A `Proc` default
is evaluated at each call, so `Date.current` is computed at query time, not at
boot; a `Proc` returning `nil` withdraws its default. Defaults go through the
same whitelisted fold as request params — a default on an undeclared name
narrows nothing — and `applied_filters` reports them like any other applied
filter.

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

### Applied filters introspection

Since an unknown or malformed filter is a silent no-op, `applied_filters` is how
a caller tells the difference: it reports, from the same params, which filters
`filterable` would actually apply — echo it in a response, or diff it against
`params[:filters]` to surface what was ignored:

```ruby
MovementDetail.applied_filters(
  filters: { value_date: { after: '2026-02-01', before: 'oops' },
             reference: 'INV-1', sort: '-value_date,+unknown' }
)
# => { 'value_date' => { 'after' => '2026-02-01' },
#      'reference'  => 'INV-1',
#      'sort'       => '-value_date' }
```

It never runs SQL and never mutates anything. A custom filter object joins the
report by responding to `applied(filters_params, scope)` next to `call`; block
filters cannot describe themselves and are simply absent.

### Validating declarations

At runtime a typo'd declaration is a silent no-op by design. To catch it in CI
instead, every model exposes a validator over its declarations:

```ruby
# in a model spec
expect(MovementDetail.filterable_declarations).to be_valid
```

`filterable_declarations.errors` lists every declaration whose column or scope
does not exist, e.g. `datable: 'date' maps to unknown column 'value_dat' on
MovementDetail` or `scopable: 'max_price' maps to unknown scope 'cheapest' on
MovementDetail`. The engine never calls it: production behavior stays a silent
no-op.

---

## Rails integration

`Filterable::Railtie` registers a single initializer that hooks
`ActiveSupport.on_load(:active_record)` and mixes the engine into
`ActiveRecord::Base`:

```ruby
include Filterable::Concern
include Filterable::Concerns::Datable
include Filterable::Concerns::Equatable
include Filterable::Concerns::Rangeable
include Filterable::Concerns::Scopable
include Filterable::Concerns::Sortable
include Filterable::Concerns::Togglable
```

So every model gains `filterable` and the `datable` / `sortable` / `equatable` /
`rangeable` / `scopable` / `togglable` DSL with no boilerplate. A model that declares no columns keeps an empty whitelist, so
`filterable` is a harmless pass-through that returns `all`.

## Outside Rails

The railtie is loaded only when `Rails::Railtie` is defined. With plain
ActiveRecord, include the pieces yourself:

```ruby
class MovementDetail < ActiveRecord::Base
  include Filterable::Concern
  include Filterable::Concerns::Datable
  include Filterable::Concerns::Equatable
  include Filterable::Concerns::Rangeable
  include Filterable::Concerns::Scopable
  include Filterable::Concerns::Sortable
  include Filterable::Concerns::Togglable

  datable   :value_date
  sortable  :value_date
  equatable :reference
  rangeable :gross_amount_cents
  scopable  :cheaper_than
  togglable :priced
end
```

> **Include order matters.** `Filterable::Concern` provides `add_filter`, which
> the declaration concerns call at include time — so it must come first.

---

## How it works

- `Filterable::Concern` keeps a per-class list of filters (cloned down the
  inheritance chain) and `filterable` reduces the relation through them.
- `Filterable::Concerns::Datable` / `Equatable` / `Rangeable` / `Scopable` /
  `Sortable` / `Togglable` are thin `ActiveSupport::Concern` mixins: they
  register the concrete filters and add the matching declaration DSL on top of
  the engine.
- The concrete date filters live under `Filterable::Datable::{After,Before,Range,Since}`,
  the equality filter is `Filterable::Equatable`, the numeric bound filters are
  `Filterable::Rangeable::{Minimum,Maximum}`, the scope filters are
  `Filterable::Scopable` / `Filterable::Togglable` and the ordering filter is
  `Filterable::Sortable`.

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
