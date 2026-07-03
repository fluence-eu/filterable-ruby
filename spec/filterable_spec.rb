# frozen_string_literal: true

# Exercised through MovementDetail (defined in spec_helper), which declares
# value_date/booking_date as datable and value_date/gross_amount_cents as sortable.
RSpec.describe Filterable::Concern do
  def detail(value_date)
    MovementDetail.create!(value_date: value_date)
  end

  let!(:january)  { detail(Date.new(2026, 1, 10)) }
  let!(:february) { detail(Date.new(2026, 2, 10)) }
  let!(:march)    { detail(Date.new(2026, 3, 10)) }

  describe '.filterable' do
    it 'returns every record when no filters are given' do
      expect(MovementDetail.filterable({})).to contain_exactly(january, february, march)
    end

    it 'returns every record when the params carry no :filters key' do
      expect(MovementDetail.filterable(page: 2)).to contain_exactly(january, february, march)
    end

    it 'keeps records strictly after a date' do
      result = MovementDetail.filterable(filters: { value_date: { after: '2026-02-01' } })
      expect(result).to contain_exactly(february, march)
    end

    it 'keeps records strictly before a date' do
      result = MovementDetail.filterable(filters: { value_date: { before: '2026-02-01' } })
      expect(result).to contain_exactly(january)
    end

    it 'keeps records since a date, bound included' do
      result = MovementDetail.filterable(filters: { value_date: { since: '2026-02-10' } })
      expect(result).to contain_exactly(january, february)
    end

    it 'keeps records within an inclusive range' do
      result = MovementDetail.filterable(filters: { value_date: { from: '2026-02-01', to: '2026-03-01' } })
      expect(result).to contain_exactly(february)
    end

    it 'combines after and before on the same attribute' do
      result = MovementDetail.filterable(filters: { value_date: { after: '2026-01-15', before: '2026-03-01' } })
      expect(result).to contain_exactly(february)
    end

    it 'ignores attributes that are not declared datable' do
      result = MovementDetail.filterable(filters: { gross_amount_cents: { after: '2026-02-01' } })
      expect(result).to contain_exactly(january, february, march)
    end

    it 'ignores an unparseable date instead of raising' do
      result = nil
      expect { result = MovementDetail.filterable(filters: { value_date: { since: 'not-a-date' } }) }
        .not_to raise_error
      expect(result).to contain_exactly(january, february, march)
    end

    it 'ignores a scalar where the date bounds are expected instead of raising' do
      result = nil
      expect { result = MovementDetail.filterable(filters: { value_date: '2026-02-01' }) }
        .not_to raise_error
      expect(result).to contain_exactly(january, february, march)
    end

    it 'ignores an array where the date bounds are expected instead of raising' do
      result = nil
      expect { result = MovementDetail.filterable(filters: { value_date: %w[2026-02-01 2026-03-01] }) }
        .not_to raise_error
      expect(result).to contain_exactly(january, february, march)
    end

    it 'accepts ActionController::Parameters from a controller' do
      params = ActionController::Parameters.new(filters: { value_date: { after: '2026-02-01' } })
      expect(MovementDetail.filterable(params)).to contain_exactly(february, march)
    end

    it 'ignores a scalar in ActionController::Parameters where the date bounds are expected' do
      params = ActionController::Parameters.new(filters: { value_date: '2026-02-01' })
      result = nil
      expect { result = MovementDetail.filterable(params) }.not_to raise_error
      expect(result).to contain_exactly(january, february, march)
    end
  end

  describe 'sortable' do
    it 'orders ascending with a leading +' do
      result = MovementDetail.filterable(filters: { sort: '+value_date' })
      expect(result.to_a).to eq([january, february, march])
    end

    it 'orders descending with a leading -' do
      result = MovementDetail.filterable(filters: { sort: '-value_date' })
      expect(result.to_a).to eq([march, february, january])
    end

    it 'defaults to ascending when no sign is given' do
      result = MovementDetail.filterable(filters: { sort: 'value_date' })
      expect(result.to_a).to eq([january, february, march])
    end

    it 'ignores attributes that are not declared sortable' do
      result = MovementDetail.filterable(filters: { sort: '-reference' })
      expect(result).to contain_exactly(january, february, march)
    end
  end

  describe 'equatable' do
    let!(:invoice) { MovementDetail.create!(reference: 'INV-1', gross_amount_cents: 100) }
    let!(:refund)  { MovementDetail.create!(reference: 'REF-2', gross_amount_cents: 250) }

    it 'keeps records equal to a scalar value' do
      result = MovementDetail.filterable(filters: { reference: 'INV-1' })
      expect(result).to contain_exactly(invoice)
    end

    it 'keeps records matching any value of an array' do
      result = MovementDetail.filterable(filters: { reference: %w[INV-1 REF-2] })
      expect(result).to contain_exactly(invoice, refund)
    end

    it 'keeps records equal to a numeric value' do
      result = MovementDetail.filterable(filters: { gross_amount_cents: 250 })
      expect(result).to contain_exactly(refund)
    end

    it 'ignores attributes that are not declared equatable' do
      result = MovementDetail.filterable(filters: { id: invoice.id })
      expect(result).to contain_exactly(january, february, march, invoice, refund)
    end

    it 'ignores a blank value instead of matching the empty string' do
      result = MovementDetail.filterable(filters: { reference: '' })
      expect(result).to contain_exactly(january, february, march, invoice, refund)
    end

    it 'ignores a non-scalar value instead of raising' do
      result = nil
      expect { result = MovementDetail.filterable(filters: { reference: { evil: 1 } }) }
        .not_to raise_error
      expect(result).to contain_exactly(january, february, march, invoice, refund)
    end

    it 'drops blank and non-scalar entries from an array value' do
      result = MovementDetail.filterable(filters: { reference: ['INV-1', '', nil, %w[nested], { evil: 1 }] })
      expect(result).to contain_exactly(invoice)
    end

    it 'ignores an array of only blank values' do
      result = MovementDetail.filterable(filters: { reference: ['', nil] })
      expect(result).to contain_exactly(january, february, march, invoice, refund)
    end

    it 'resolves a public name onto its aliased column' do
      model = Class.new(MovementDetail) { equatable ref: :reference }

      expect(model.filterable(filters: { ref: 'INV-1' }).map(&:id)).to eq([invoice.id])
    end

    it 'inherits the equatable declarations in a subclass' do
      result = Class.new(MovementDetail).filterable(filters: { reference: 'INV-1' })

      expect(result.map(&:id)).to eq([invoice.id])
    end

    it 'accepts ActionController::Parameters from a controller' do
      params = ActionController::Parameters.new(filters: { reference: 'INV-1' })
      expect(MovementDetail.filterable(params).map(&:id)).to eq([invoice.id])
    end
  end

  describe 'rangeable' do
    let!(:cheap)  { MovementDetail.create!(gross_amount_cents: 100) }
    let!(:mid)    { MovementDetail.create!(gross_amount_cents: 250) }
    let!(:pricey) { MovementDetail.create!(gross_amount_cents: 400) }

    it 'keeps records at or above min, bound included' do
      result = MovementDetail.filterable(filters: { gross_amount_cents: { min: 250 } })
      expect(result).to contain_exactly(mid, pricey)
    end

    it 'keeps records at or below max, bound included' do
      result = MovementDetail.filterable(filters: { gross_amount_cents: { max: '250' } })
      expect(result).to contain_exactly(cheap, mid)
    end

    it 'combines min and max into an inclusive range' do
      result = MovementDetail.filterable(filters: { gross_amount_cents: { min: '150', max: '399' } })
      expect(result).to contain_exactly(mid)
    end

    it 'keeps a zero bound instead of dropping it as blank' do
      result = MovementDetail.filterable(filters: { gross_amount_cents: { min: 0 } })
      expect(result).to contain_exactly(cheap, mid, pricey)
    end

    it 'parses a decimal bound' do
      result = MovementDetail.filterable(filters: { gross_amount_cents: { max: '250.5' } })
      expect(result).to contain_exactly(cheap, mid)
    end

    it 'ignores an unparseable bound instead of raising' do
      result = nil
      expect { result = MovementDetail.filterable(filters: { gross_amount_cents: { min: 'cheap' } }) }
        .not_to raise_error
      expect(result).to contain_exactly(january, february, march, cheap, mid, pricey)
    end

    it 'ignores a blank bound' do
      result = MovementDetail.filterable(filters: { gross_amount_cents: { min: '' } })
      expect(result).to contain_exactly(january, february, march, cheap, mid, pricey)
    end

    it 'ignores attributes that are not declared rangeable' do
      result = MovementDetail.filterable(filters: { reference: { min: 'A' } })
      expect(result).to contain_exactly(january, february, march, cheap, mid, pricey)
    end

    it 'ignores a scalar where the bounds are expected instead of raising' do
      model = Class.new(MovementDetail) { rangeable amount: :gross_amount_cents }
      result = nil
      expect { result = model.filterable(filters: { amount: '100' }) }.not_to raise_error
      expect(result.count).to eq(6)
    end

    it 'composes with equatable on the same column: a scalar filters by equality' do
      result = MovementDetail.filterable(filters: { gross_amount_cents: '100' })
      expect(result).to contain_exactly(cheap)
    end

    it 'composes with equatable on the same column: bounds filter by range' do
      result = MovementDetail.filterable(filters: { gross_amount_cents: { min: 300 } })
      expect(result).to contain_exactly(pricey)
    end

    it 'resolves a public name onto its aliased column' do
      model = Class.new(MovementDetail) { rangeable amount: :gross_amount_cents }

      expect(model.filterable(filters: { amount: { min: 300 } }).map(&:id)).to eq([pricey.id])
    end

    it 'inherits the rangeable declarations in a subclass' do
      result = Class.new(MovementDetail).filterable(filters: { gross_amount_cents: { min: 300 } })

      expect(result.map(&:id)).to eq([pricey.id])
    end

    it 'accepts ActionController::Parameters from a controller' do
      params = ActionController::Parameters.new(filters: { gross_amount_cents: { min: '300' } })
      expect(MovementDetail.filterable(params).map(&:id)).to eq([pricey.id])
    end
  end

  describe 'matchable' do
    let!(:invoice) { MovementDetail.create!(reference: 'INV-100') }
    let!(:refund)  { MovementDetail.create!(reference: 'REF-INV') }
    let!(:percent) { MovementDetail.create!(reference: '100%') }
    let!(:under)   { MovementDetail.create!(reference: 'A_B') }
    let!(:cross)   { MovementDetail.create!(reference: 'AXB') }

    it 'matches the start of the column' do
      result = MovementDetail.filterable(filters: { reference: { starts_with: 'INV' } })
      expect(result).to contain_exactly(invoice)
    end

    it 'matches the end of the column' do
      result = MovementDetail.filterable(filters: { reference: { ends_with: 'INV' } })
      expect(result).to contain_exactly(refund)
    end

    it 'matches anywhere in the column' do
      result = MovementDetail.filterable(filters: { reference: { contains: 'INV' } })
      expect(result).to contain_exactly(invoice, refund)
    end

    it 'matches case insensitively by default' do
      result = MovementDetail.filterable(filters: { reference: { starts_with: 'inv' } })
      expect(result).to contain_exactly(invoice)
    end

    it 'escapes percent signs in the term' do
      expect(MovementDetail.filterable(filters: { reference: { contains: '%' } })).to contain_exactly(percent)
      expect(MovementDetail.filterable(filters: { reference: { contains: '0%' } })).to contain_exactly(percent)
    end

    it 'escapes underscores in the term' do
      result = MovementDetail.filterable(filters: { reference: { contains: 'A_B' } })
      expect(result).to contain_exactly(under)
    end

    it 'combines several match keys on the same attribute' do
      result = MovementDetail.filterable(filters: { reference: { starts_with: 'INV', contains: '100' } })
      expect(result).to contain_exactly(invoice)
    end

    it 'ignores blank and non-string terms and non-hash values' do
      cases = [{ reference: { contains: '' } }, { reference: { contains: ['a'] } }, { matched_account: 'INV' }]
      cases.each do |filters|
        result = nil
        expect { result = MovementDetail.filterable(filters: filters) }.not_to raise_error
        expect(result.count).to eq(8)
      end
    end

    it 'renders ILIKE by default and LIKE when declared case sensitive' do
      sensitive_model = Class.new(MovementDetail) { matchable code: :reference, case_sensitive: true }
      insensitive = MovementDetail.filterable(filters: { reference: { starts_with: 'INV' } })
      sensitive = sensitive_model.filterable(filters: { code: { starts_with: 'INV' } })
      visitor = Arel::Visitors::PostgreSQL.new(MovementDetail.connection)

      expect(visitor.compile(insensitive.arel.ast)).to include('ILIKE')
      expect(visitor.compile(sensitive.arel.ast)).not_to include('ILIKE')
    end

    it 'matches case sensitively end to end when the adapter enforces it' do
      model = Class.new(MovementDetail) { matchable code: :reference, case_sensitive: true }
      MovementDetail.connection.execute('PRAGMA case_sensitive_like = ON')

      expect(model.filterable(filters: { code: { starts_with: 'inv' } }).count).to eq(0)
      expect(model.filterable(filters: { code: { starts_with: 'INV' } }).map(&:id)).to eq([invoice.id])
    ensure
      MovementDetail.connection.execute('PRAGMA case_sensitive_like = OFF')
    end

    it 'matches through an association target' do
      detail = MovementDetail.create!(account: Account.create!(name: 'Main'))

      result = MovementDetail.filterable(filters: { matched_account: { contains: 'ai' } })
      expect(result).to contain_exactly(detail)
    end

    it 'does not mutate the declaration hash' do
      declaration = { code: :reference, case_sensitive: true }
      Class.new(MovementDetail).matchable(declaration)

      expect(declaration).to eq(code: :reference, case_sensitive: true)
    end

    it 'inherits the matchable declarations in a subclass' do
      result = Class.new(MovementDetail).filterable(filters: { reference: { starts_with: 'INV' } })
      expect(result.map(&:id)).to eq([invoice.id])
    end

    it 'reports the accepted terms in applied_filters' do
      report = MovementDetail.applied_filters(
        filters: { reference: { starts_with: 'IN', ends_with: '0', contains: 'V', until: '' } }
      )

      expect(report[:reference]).to eq('starts_with' => 'IN', 'ends_with' => '0', 'contains' => 'V')
    end

    it 'accepts ActionController::Parameters from a controller' do
      params = ActionController::Parameters.new(filters: { reference: { starts_with: 'INV' } })
      expect(MovementDetail.filterable(params)).to contain_exactly(invoice)
    end
  end

  describe 'association targets' do
    let!(:bank)    { Bank.create!(name: 'BNP') }
    let!(:main)    { Account.create!(name: 'Main', balance_cents: 1000, opened_on: Date.new(2026, 1, 1), bank: bank) }
    let!(:savings) { Account.create!(name: 'Savings', balance_cents: 5000) }
    let!(:main_detail)    { MovementDetail.create!(account: main, reference: 'M-1') }
    let!(:savings_detail) { MovementDetail.create!(account: savings, reference: 'S-1') }

    it 'filters by equality through a belongs_to and drops rows without it' do
      result = MovementDetail.filterable(filters: { account_name: 'Main' })
      expect(result).to contain_exactly(main_detail)
    end

    it 'filters through a nested association path' do
      result = MovementDetail.filterable(filters: { bank_name: 'BNP' })
      expect(result).to contain_exactly(main_detail)
    end

    it 'applies numeric bounds on the associated column' do
      result = MovementDetail.filterable(filters: { account_balance: { min: 2000 } })
      expect(result).to contain_exactly(savings_detail)
    end

    it 'applies date bounds on the associated column' do
      result = MovementDetail.filterable(filters: { account_opened: { after: '2025-12-31' } })
      expect(result).to contain_exactly(main_detail)
    end

    it 'deduplicates rows when filtering through a collection' do
      MovementDetail.create!(account: main, reference: 'DUP')
      MovementDetail.create!(account: main, reference: 'DUP')

      result = Account.filterable(filters: { detail_reference: 'DUP' })
      expect(result.map(&:id)).to eq([main.id])
    end

    it 'ignores a declared target walking an unknown association instead of raising' do
      model = Class.new(MovementDetail) { equatable broken: { nope: :name } }
      result = nil
      expect { result = model.filterable(filters: { broken: 'x' }) }.not_to raise_error
      expect(result.count).to eq(5)
    end

    it 'ignores a declared target through a polymorphic association instead of raising' do
      model = Class.new(MovementDetail) { equatable att_name: { attachable: :name } }
      result = nil
      expect { result = model.filterable(filters: { att_name: 'x' }) }.not_to raise_error
      expect(result.count).to eq(5)
    end

    it 'ignores an ambiguous association target instead of raising' do
      model = Class.new(MovementDetail) { equatable weird: { account: :name, bank: :name } }

      expect(model.filterable(filters: { weird: 'x' }).count).to eq(5)
    end

    it 'ignores an association target declared sortable' do
      model = Class.new(MovementDetail) { sortable acc_name: { account: :name } }

      expect(model.filterable(filters: { sort: '-acc_name' }).count).to eq(5)
    end

    it 'ignores an association target declared scopable instead of raising' do
      model = Class.new(MovementDetail) { scopable weird: { account: :name } }
      result = nil
      expect { result = model.filterable(filters: { weird: 'x' }) }.not_to raise_error
      expect(result.count).to eq(5)
    end

    it 'ignores an association target declared togglable instead of raising' do
      model = Class.new(MovementDetail) { togglable weird: { account: :name } }

      expect { model.filterable(filters: { weird: 'true' }) }.not_to raise_error
    end

    it 'filters through a delegated type, guarded by the concrete type column' do
      x_bank = Bank.create!(id: 4242, name: 'X')
      x_account = Account.create!(id: 4242, name: 'X')
      bank_detail = MovementDetail.create!(attachable: x_bank)
      MovementDetail.create!(attachable: x_account)

      result = MovementDetail.filterable(filters: { attached_bank_name: 'X' })
      expect(result).to contain_exactly(bank_detail)
    end

    it 'applies bounds through a delegated type' do
      rich = Account.create!(name: 'Rich', balance_cents: 9000)
      rich_detail = MovementDetail.create!(attachable: rich)

      result = MovementDetail.filterable(filters: { attached_balance: { min: 8000 } })
      expect(result).to contain_exactly(rich_detail)
    end

    it 'filters through a bare polymorphic belongs_to, without delegated_type' do
      src = Account.create!(name: 'Src')
      sourced_detail = MovementDetail.create!(source: src)

      result = MovementDetail.filterable(filters: { source_account_name: 'Src' })
      expect(result).to contain_exactly(sourced_detail)
    end

    it 'ignores a delegated-type target with an unknown concrete type instead of raising' do
      model = Class.new(MovementDetail) { equatable ghost: { attachable: { spaceship: :name } } }
      result = nil
      expect { result = model.filterable(filters: { ghost: 'x' }) }.not_to raise_error
      expect(result.count).to eq(5)
    end

    it 'ignores a delegated-type target whose type is not a model' do
      model = Class.new(MovementDetail) { equatable ghost: { attachable: { string: :name } } }

      expect(model.filterable(filters: { ghost: 'x' }).count).to eq(5)
    end

    it 'reports association-target filters in applied_filters' do
      report = MovementDetail.applied_filters(filters: { account_name: 'Main' })

      expect(report[:account_name]).to eq('Main')
    end

    it 'accepts ActionController::Parameters from a controller' do
      params = ActionController::Parameters.new(filters: { account_name: 'Main' })
      expect(MovementDetail.filterable(params)).to contain_exactly(main_detail)
    end
  end

  describe 'scopable' do
    let!(:cheap) { MovementDetail.create!(gross_amount_cents: 100) }
    let!(:mid)   { MovementDetail.create!(gross_amount_cents: 250) }

    it 'passes the value to the declared scope' do
      result = MovementDetail.filterable(filters: { cheaper_than: 250 })
      expect(result).to contain_exactly(cheap)
    end

    it 'passes a string value, letting the scope cast it' do
      result = MovementDetail.filterable(filters: { cheaper_than: '250' })
      expect(result).to contain_exactly(cheap)
    end

    it 'ignores a blank value' do
      result = MovementDetail.filterable(filters: { cheaper_than: '' })
      expect(result).to contain_exactly(january, february, march, cheap, mid)
    end

    it 'ignores a non-scalar value instead of raising' do
      result = nil
      expect { result = MovementDetail.filterable(filters: { cheaper_than: { evil: 1 } }) }
        .not_to raise_error
      expect(result).to contain_exactly(january, february, march, cheap, mid)
    end

    it 'ignores scopes that exist on the model but are not declared scopable' do
      result = MovementDetail.filterable(filters: { costlier_than: 50 })
      expect(result).to contain_exactly(january, february, march, cheap, mid)
    end

    it 'ignores a declared name whose scope does not exist instead of raising' do
      model = Class.new(MovementDetail) { scopable :does_not_exist }
      result = nil
      expect { result = model.filterable(filters: { does_not_exist: 1 }) }.not_to raise_error
      expect(result.count).to eq(5)
    end

    it 'leaves the relation untouched when the scope does not return a relation' do
      model = Class.new(MovementDetail) do
        def self.broken(_value)
          nil
        end
        scopable :broken
      end

      expect(model.filterable(filters: { broken: 1 }).count).to eq(5)
    end

    it 'resolves a public name onto its aliased scope' do
      model = Class.new(MovementDetail) { scopable max_price: :cheaper_than }

      expect(model.filterable(filters: { max_price: 250 }).map(&:id)).to eq([cheap.id])
    end

    it 'inherits the scopable declarations in a subclass' do
      result = Class.new(MovementDetail).filterable(filters: { cheaper_than: 250 })

      expect(result.map(&:id)).to eq([cheap.id])
    end

    it 'accepts ActionController::Parameters from a controller' do
      params = ActionController::Parameters.new(filters: { cheaper_than: '250' })
      expect(MovementDetail.filterable(params).map(&:id)).to eq([cheap.id])
    end

    it 'reports the normalized value in applied_filters' do
      report = MovementDetail.applied_filters(filters: { cheaper_than: '250' })

      expect(report[:cheaper_than]).to eq('250')
    end

    it 'omits a declared name whose scope does not exist from applied_filters' do
      model = Class.new(MovementDetail) { scopable :does_not_exist }

      expect(model.applied_filters(filters: { does_not_exist: 1 })).to be_empty
    end
  end

  describe 'togglable' do
    let!(:cheap) { MovementDetail.create!(gross_amount_cents: 100) }
    let!(:mid)   { MovementDetail.create!(gross_amount_cents: 250) }

    it 'applies the scope when the value is a true-ish string' do
      result = MovementDetail.filterable(filters: { priced: 'true' })
      expect(result).to contain_exactly(cheap, mid)
    end

    it 'accepts every strict true value' do
      [true, 1, '1'].each do |value|
        expect(MovementDetail.filterable(filters: { priced: value })).to contain_exactly(cheap, mid)
      end
    end

    it 'ignores false values' do
      [false, 0, '0', 'false'].each do |value|
        expect(MovementDetail.filterable(filters: { priced: value }))
          .to contain_exactly(january, february, march, cheap, mid)
      end
    end

    it 'ignores an arbitrary string instead of treating it as true' do
      result = MovementDetail.filterable(filters: { priced: 'garbage' })
      expect(result).to contain_exactly(january, february, march, cheap, mid)
    end

    it 'toggles on a bare key carrying a blank value' do
      ['', '  ', nil].each do |value|
        expect(MovementDetail.filterable(filters: { priced: value })).to contain_exactly(cheap, mid)
      end
    end

    it 'toggles on a bare key from ActionController::Parameters' do
      params = ActionController::Parameters.new(filters: { priced: nil })
      expect(MovementDetail.filterable(params).map(&:id)).to contain_exactly(cheap.id, mid.id)
    end

    it 'ignores a declared name whose scope does not exist instead of raising' do
      model = Class.new(MovementDetail) { togglable :does_not_exist }
      result = nil
      expect { result = model.filterable(filters: { does_not_exist: 'true' }) }.not_to raise_error
      expect(result.count).to eq(5)
    end

    it 'leaves the relation untouched when the scope does not return a relation' do
      model = Class.new(MovementDetail) do
        def self.broken
          nil
        end
        togglable :broken
      end

      expect(model.filterable(filters: { broken: 'true' }).count).to eq(5)
    end

    it 'resolves a public name onto its aliased scope' do
      model = Class.new(MovementDetail) { togglable has_price: :priced }

      expect(model.filterable(filters: { has_price: 'true' }).map(&:id)).to contain_exactly(cheap.id, mid.id)
    end

    it 'inherits the togglable declarations in a subclass' do
      result = Class.new(MovementDetail).filterable(filters: { priced: 'true' })

      expect(result.map(&:id)).to contain_exactly(cheap.id, mid.id)
    end

    it 'reports true in applied_filters' do
      report = MovementDetail.applied_filters(filters: { priced: '1' })

      expect(report[:priced]).to be(true)
    end

    it 'reports true in applied_filters for a bare key' do
      report = MovementDetail.applied_filters(filters: { priced: '' })

      expect(report[:priced]).to be(true)
    end

    it 'stays out of applied_filters when the value is not true-ish' do
      expect(MovementDetail.applied_filters(filters: { priced: 'garbage' })).to be_empty
    end
  end

  describe '.add_filter' do
    it 'folds a block filter over the relation like any filter object' do
      model = Class.new(MovementDetail) do
        add_filter do |filters_params, scope|
          scope.where(value_date: ..Date.parse(filters_params[:until])) if filters_params[:until]
        end
      end

      expect(model.filterable(filters: { until: '2026-01-31' }).map(&:id)).to eq([january.id])
    end
  end

  describe 'call context' do
    let!(:mine) { MovementDetail.create!(reference: 'MINE') }

    it 'hands the context to a block filter declaring a third parameter' do
      model = Class.new(MovementDetail) do
        add_filter do |filters_params, scope, context|
          scope.where(reference: context[:ref]) if filters_params[:mine]
        end
      end

      result = model.filterable({ filters: { mine: '1' } }, ref: 'MINE')
      expect(result.map(&:id)).to eq([mine.id])
    end

    it 'hands the context to an object filter with an optional third parameter' do
      custom = Module.new do
        def self.call(filters_params, scope, context = {})
          scope.where(reference: context[:ref]) if filters_params[:mine]
        end
      end
      model = Class.new(MovementDetail)
      model.add_filter(custom)

      result = model.filterable({ filters: { mine: '1' } }, ref: 'MINE')
      expect(result.map(&:id)).to eq([mine.id])
    end

    it 'keeps two-parameter filters untouched by the context' do
      result = MovementDetail.filterable({ filters: { value_date: { after: '2026-02-01' } } }, user_id: 42)

      expect(result).to contain_exactly(february, march)
    end

    it 'defaults the context to an empty hash' do
      model = Class.new(MovementDetail) do
        add_filter do |filters_params, scope, context|
          scope.where(reference: context.fetch(:ref, 'NONE')) if filters_params[:mine]
        end
      end

      expect(model.filterable(filters: { mine: '1' })).to be_empty
    end

    it 'hands the context to a context-aware applied' do
      custom = Module.new do
        def self.call(filters_params, scope, context = {})
          scope.where(reference: context[:ref]) if filters_params[:mine]
        end

        def self.applied(filters_params, _scope, context = {})
          filters_params[:mine] ? { mine: context[:ref] } : {}
        end
      end
      model = Class.new(MovementDetail)
      model.add_filter(custom)

      expect(model.applied_filters({ filters: { mine: '1' } }, ref: 'MINE')[:mine]).to eq('MINE')
    end
  end

  describe '.applied_filters' do
    it 'returns an empty report when no filters are given' do
      expect(MovementDetail.applied_filters({})).to be_empty
    end

    it 'returns an empty report when the params carry no :filters key' do
      expect(MovementDetail.applied_filters(page: 2)).to be_empty
    end

    it 'reports an accepted date bound with its raw value' do
      report = MovementDetail.applied_filters(filters: { value_date: { after: '2026-02-01' } })

      expect(report).to eq('value_date' => { 'after' => '2026-02-01' })
    end

    it 'merges several accepted bounds under the same attribute' do
      report = MovementDetail.applied_filters(
        filters: { value_date: { after: '2026-01-15', before: '2026-03-01' } }
      )

      expect(report[:value_date]).to eq('after' => '2026-01-15', 'before' => '2026-03-01')
    end

    it 'reports an accepted since bound with its raw value' do
      report = MovementDetail.applied_filters(filters: { value_date: { since: '2026-02-10' } })

      expect(report[:value_date]).to eq('since' => '2026-02-10')
    end

    it 'omits an unparseable date bound' do
      report = MovementDetail.applied_filters(filters: { value_date: { since: 'not-a-date' } })

      expect(report).to be_empty
    end

    it 'omits a range missing one of its two bounds' do
      report = MovementDetail.applied_filters(filters: { value_date: { from: '2026-02-01' } })

      expect(report).to be_empty
    end

    it 'reports a full range with both raw bounds' do
      report = MovementDetail.applied_filters(filters: { value_date: { from: '2026-02-01', to: '2026-03-01' } })

      expect(report[:value_date]).to eq('from' => '2026-02-01', 'to' => '2026-03-01')
    end

    it 'reports an equality filter with its normalized value' do
      report = MovementDetail.applied_filters(filters: { reference: ['INV-1', '', nil] })

      expect(report[:reference]).to eq(['INV-1'])
    end

    it 'omits a blank equality value' do
      expect(MovementDetail.applied_filters(filters: { reference: '' })).to be_empty
    end

    it 'reports an accepted numeric bound with its raw value' do
      report = MovementDetail.applied_filters(filters: { gross_amount_cents: { min: '100' } })

      expect(report[:gross_amount_cents]).to eq('min' => '100')
    end

    it 'omits an unparseable numeric bound' do
      expect(MovementDetail.applied_filters(filters: { gross_amount_cents: { min: 'cheap' } })).to be_empty
    end

    it 'reports only the accepted sort terms' do
      report = MovementDetail.applied_filters(filters: { sort: '-value_date,+reference' })

      expect(report[:sort]).to eq('-value_date')
    end

    it 'omits the sort when no term is declared sortable' do
      expect(MovementDetail.applied_filters(filters: { sort: '-reference' })).to be_empty
    end

    it 'reports every kind at once with indifferent access' do
      report = MovementDetail.applied_filters(
        filters: { value_date: { after: '2026-02-01' }, reference: 'INV-1',
                   gross_amount_cents: { max: 250 }, sort: '-value_date' }
      )

      expect(report['value_date']).to eq('after' => '2026-02-01')
      expect(report[:reference]).to eq('INV-1')
      expect(report[:gross_amount_cents]).to eq('max' => 250)
      expect(report[:sort]).to eq('-value_date')
    end

    it 'accepts ActionController::Parameters from a controller' do
      params = ActionController::Parameters.new(filters: { reference: 'INV-1' })

      expect(MovementDetail.applied_filters(params)[:reference]).to eq('INV-1')
    end

    it 'skips block filters, which cannot describe what they applied' do
      model = Class.new(MovementDetail) do
        add_filter do |filters_params, scope|
          scope.where(value_date: ..Date.parse(filters_params[:until])) if filters_params[:until]
        end
      end

      expect(model.applied_filters(filters: { until: '2026-01-31' })).to be_empty
    end

    it 'includes a custom filter object that implements applied' do
      custom = Module.new do
        def self.call(filters_params, scope)
          scope.where(value_date: ..Date.parse(filters_params[:until])) if filters_params[:until]
        end

        def self.applied(filters_params, _scope)
          filters_params[:until] ? { until: filters_params[:until] } : {}
        end
      end
      model = Class.new(MovementDetail)
      model.add_filter(custom)

      expect(model.applied_filters(filters: { until: '2026-01-31' })).to eq('until' => '2026-01-31')
    end
  end

  describe '.default_filters' do
    let(:model) { Class.new(MovementDetail) }

    it 'applies a default sort when the params carry nothing' do
      model.default_filters(sort: '-value_date')

      expect(model.filterable({}).map(&:id)).to eq([march.id, february.id, january.id])
    end

    it 'applies a default filter value when the key is absent' do
      model.default_filters(value_date: { after: '2026-01-15' })

      expect(model.filterable({}).map(&:id)).to contain_exactly(february.id, march.id)
    end

    it 'lets a request value override its default' do
      model.default_filters(sort: '-value_date')

      result = model.filterable(filters: { sort: '+value_date' })
      expect(result.map(&:id)).to eq([january.id, february.id, march.id])
    end

    it 'suppresses the default when the key is present, even blank' do
      model.default_filters(value_date: { after: '2026-01-15' })

      result = model.filterable(filters: { value_date: '' })
      expect(result.map(&:id)).to contain_exactly(january.id, february.id, march.id)
    end

    it 'combines a default with requested filters on other keys' do
      model.default_filters(sort: '-value_date')

      result = model.filterable(filters: { value_date: { after: '2026-01-15' } })
      expect(result.map(&:id)).to eq([march.id, february.id])
    end

    it 'evaluates a proc default at each call' do
      bound = '2026-03-01'
      model.default_filters(value_date: -> { { after: bound } })

      expect(model.filterable({}).map(&:id)).to contain_exactly(march.id)
      bound = '2026-01-15'
      expect(model.filterable({}).map(&:id)).to contain_exactly(february.id, march.id)
    end

    it 'treats a proc returning nil as no default' do
      model.default_filters(sort: -> {})

      expect(model.filterable({}).map(&:id)).to contain_exactly(january.id, february.id, march.id)
      expect(model.applied_filters({})).to be_empty
    end

    it 'keeps a default on an undeclared name a silent no-op' do
      model.default_filters(bogus: 'x')

      result = nil
      expect { result = model.filterable({}) }.not_to raise_error
      expect(result.map(&:id)).to contain_exactly(january.id, february.id, march.id)
    end

    it 'applies defaults when the filters params are unusable' do
      model.default_filters(value_date: { after: '2026-01-15' })

      expect(model.filterable(filters: 'garbage').map(&:id)).to contain_exactly(february.id, march.id)
    end

    it 'reports the effective defaults in applied_filters' do
      model.default_filters(sort: '-value_date')

      expect(model.applied_filters({})[:sort]).to eq('-value_date')
    end

    it 'merges ActionController::Parameters over the defaults' do
      model.default_filters(sort: '-value_date')
      params = ActionController::Parameters.new(filters: { sort: '+value_date' })

      expect(model.filterable(params).map(&:id)).to eq([january.id, february.id, march.id])
    end

    it 'inherits the defaults in a subclass without leaking additions to the parent' do
      model.default_filters(sort: '-value_date')
      subclass = Class.new(model)
      subclass.default_filters(value_date: { after: '2026-01-15' })

      expect(subclass.filterable({}).map(&:id)).to eq([march.id, february.id])
      expect(model.default_filter_params).not_to have_key(:value_date)
    end

    it 'ignores a non-hash declaration' do
      model.default_filters(42)

      expect(model.default_filter_params).to be_empty
    end
  end

  describe '.filterable_declarations' do
    it 'is valid when every declaration maps onto a real column' do
      validator = MovementDetail.filterable_declarations

      expect(validator).to be_valid
      expect(validator.errors).to be_empty
    end

    it 'reports a datable declaration pointing to an unknown column' do
      stub_const('BrokenDetail', Class.new(MovementDetail) { datable :value_dat })
      validator = BrokenDetail.filterable_declarations

      expect(validator).not_to be_valid
      expect(validator.errors).to contain_exactly(
        "datable: 'value_dat' maps to unknown column 'value_dat' on BrokenDetail"
      )
    end

    it 'reports a sortable declaration pointing to an unknown column through its alias' do
      stub_const('BrokenSort', Class.new(MovementDetail) { sortable amount: :gross_amount })
      validator = BrokenSort.filterable_declarations

      expect(validator).not_to be_valid
      expect(validator.errors).to contain_exactly(
        "sortable: 'amount' maps to unknown column 'gross_amount' on BrokenSort"
      )
    end

    it 'reports a rangeable declaration pointing to an unknown column' do
      stub_const('BrokenRange', Class.new(MovementDetail) { rangeable :gross_amount })
      validator = BrokenRange.filterable_declarations

      expect(validator).not_to be_valid
      expect(validator.errors).to contain_exactly(
        "rangeable: 'gross_amount' maps to unknown column 'gross_amount' on BrokenRange"
      )
    end

    it 'reports a scopable declaration pointing to an unknown scope' do
      stub_const('BrokenScope', Class.new(MovementDetail) { scopable :nonexistent })
      validator = BrokenScope.filterable_declarations

      expect(validator).not_to be_valid
      expect(validator.errors).to contain_exactly(
        "scopable: 'nonexistent' maps to unknown scope 'nonexistent' on BrokenScope"
      )
    end

    it 'reports a togglable declaration pointing to an unknown scope through its alias' do
      stub_const('BrokenToggle', Class.new(MovementDetail) { togglable active: :nonexistent })
      validator = BrokenToggle.filterable_declarations

      expect(validator).not_to be_valid
      expect(validator.errors).to contain_exactly(
        "togglable: 'active' maps to unknown scope 'nonexistent' on BrokenToggle"
      )
    end

    it 'reports an attachable declaration without the generated attachment associations' do
      stub_const('NoAttach', Class.new(MovementDetail) { attachable :document })
      validator = NoAttach.filterable_declarations

      expect(validator).not_to be_valid
      expect(validator.errors).to contain_exactly(
        "attachable: 'document' maps to unknown attachment 'document' on NoAttach"
      )
    end

    it 'reports a matchable declaration pointing to an unknown column' do
      stub_const('BrokenMatch', Class.new(MovementDetail) { matchable :referemce })
      validator = BrokenMatch.filterable_declarations

      expect(validator).not_to be_valid
      expect(validator.errors).to contain_exactly(
        "matchable: 'referemce' maps to unknown column 'referemce' on BrokenMatch"
      )
    end

    it 'is valid for association targets resolving to real columns' do
      expect(Account.filterable_declarations).to be_valid
    end

    it 'reports an association target walking an unresolvable path' do
      stub_const('BrokenPath', Class.new(MovementDetail) { equatable acc: { nonexistent: :name } })
      validator = BrokenPath.filterable_declarations

      expect(validator).not_to be_valid
      expect(validator.errors).to contain_exactly(
        "equatable: 'acc' walks an unresolvable association path 'nonexistent' on BrokenPath"
      )
    end

    it 'reports a polymorphic association target as unresolvable' do
      stub_const('PolyPath', Class.new(MovementDetail) { equatable att: { attachable: :name } })

      expect(PolyPath.filterable_declarations.errors).to contain_exactly(
        "equatable: 'att' walks an unresolvable association path 'attachable' on PolyPath"
      )
    end

    it 'reports an association target pointing to an unknown column on the target model' do
      stub_const('BrokenColumn', Class.new(MovementDetail) { equatable acc: { account: :iban } })

      expect(BrokenColumn.filterable_declarations.errors).to contain_exactly(
        "equatable: 'acc' maps to unknown column 'iban' on Account"
      )
    end

    it 'reports an ambiguous association target' do
      stub_const('Ambiguous', Class.new(MovementDetail) { equatable acc: { account: :name, bank: :name } })

      expect(Ambiguous.filterable_declarations.errors).to contain_exactly(
        "equatable: 'acc' has an ambiguous association target on Ambiguous"
      )
    end

    it 'reports a delegated-type target with an unknown concrete type' do
      stub_const('GhostType', Class.new(MovementDetail) { equatable g: { attachable: { spaceship: :name } } })

      expect(GhostType.filterable_declarations.errors).to contain_exactly(
        "equatable: 'g' walks an unresolvable association path 'attachable.spaceship' on GhostType"
      )
    end

    it 'reports a delegated-type target pointing to an unknown column on the concrete type' do
      stub_const('GhostColumn', Class.new(MovementDetail) { equatable g: { attachable: { bank: :iban } } })

      expect(GhostColumn.filterable_declarations.errors).to contain_exactly(
        "equatable: 'g' maps to unknown column 'iban' on Bank"
      )
    end

    it 'reports an association target declared sortable as unsupported' do
      stub_const('SortPath', Class.new(MovementDetail) { sortable acc: { account: :name } })

      expect(SortPath.filterable_declarations.errors).to contain_exactly(
        "sortable: 'acc' cannot sort through an association"
      )
    end

    it 'is valid for a model without any declaration DSL' do
      model = Class.new { include Filterable::Concern }

      expect(model.filterable_declarations).to be_valid
    end
  end

  describe 'declarations' do
    let(:model) do
      Class.new do
        include Filterable::Concern
        include Filterable::Concerns::Datable
        include Filterable::Concerns::Sortable
        include Filterable::Concerns::Equatable
        include Filterable::Concerns::Rangeable
        include Filterable::Concerns::Scopable
        include Filterable::Concerns::Togglable
        include Filterable::Concerns::Attachable
        include Filterable::Concerns::Matchable
      end
    end

    it 'maps a bare attribute onto its own column' do
      model.datable(:value_date).sortable(:value_date).equatable(:reference).rangeable(:gross_amount_cents)
           .scopable(:cheaper_than).togglable(:priced).attachable(:document).matchable(:reference)

      expect(model.datable_attribute_names[:value_date]).to eq(:value_date)
      expect(model.sortable_attribute_names[:value_date]).to eq(:value_date)
      expect(model.equatable_attribute_names[:reference]).to eq(:reference)
      expect(model.rangeable_attribute_names[:gross_amount_cents]).to eq(:gross_amount_cents)
      expect(model.scopable_scope_names[:cheaper_than]).to eq(:cheaper_than)
      expect(model.togglable_scope_names[:priced]).to eq(:priced)
      expect(model.attachable_attachment_names[:document]).to eq(:document)
      expect(model.matchable_attribute_names[:reference]).to eq(:reference)
      expect(model.matchable_case_sensitive).to be_empty
    end

    it 'aliases a public name to a column through a hash' do
      model.datable(date: :value_date).sortable(amount: :gross_amount_cents).equatable(ref: :reference)
           .rangeable(amount: :gross_amount_cents).scopable(max_price: :cheaper_than).togglable(has_price: :priced)
           .attachable(file: :document).matchable(code: :reference, case_sensitive: true)

      expect(model.datable_attribute_names[:date]).to eq(:value_date)
      expect(model.sortable_attribute_names[:amount]).to eq(:gross_amount_cents)
      expect(model.equatable_attribute_names[:ref]).to eq(:reference)
      expect(model.rangeable_attribute_names[:amount]).to eq(:gross_amount_cents)
      expect(model.scopable_scope_names[:max_price]).to eq(:cheaper_than)
      expect(model.togglable_scope_names[:has_price]).to eq(:priced)
      expect(model.attachable_attachment_names[:file]).to eq(:document)
      expect(model.matchable_attribute_names[:code]).to eq(:reference)
      expect(model.matchable_case_sensitive[:code]).to be(true)
    end

    it 'ignores an unsupported declaration' do
      model.datable(42).sortable(nil).equatable(3.14).rangeable(Object.new).scopable(42).togglable(nil)
           .attachable(1.5).matchable(42)

      expect(model.datable_attribute_names).to be_empty
      expect(model.sortable_attribute_names).to be_empty
      expect(model.equatable_attribute_names).to be_empty
      expect(model.rangeable_attribute_names).to be_empty
      expect(model.scopable_scope_names).to be_empty
      expect(model.togglable_scope_names).to be_empty
      expect(model.attachable_attachment_names).to be_empty
      expect(model.matchable_attribute_names).to be_empty
    end
  end

  describe 'attachable without ActiveStorage' do
    it 'ignores a declared attachment when the model has no generated associations' do
      model = Class.new(MovementDetail) { attachable :document }
      result = nil
      expect { result = model.filterable(filters: { document: { present: 'true' } }) }.not_to raise_error
      expect(result.count).to eq(3)
    end

    it 'ignores a scalar where the attachment keys are expected instead of raising' do
      model = Class.new(MovementDetail) { attachable :document }

      expect { model.filterable(filters: { document: 'x' }) }.not_to raise_error
    end

    it 'stays out of applied_filters' do
      model = Class.new(MovementDetail) { attachable :document }

      expect(model.applied_filters(filters: { document: { present: 'true' } })).to be_empty
    end

    it 'does not mistake an ordinary association named like an attachment' do
      stub_const('FakeAttach', Class.new(MovementDetail) do
        belongs_to :document_attachment, class_name: 'Account', optional: true
        attachable :document
      end)

      result = nil
      expect { result = FakeAttach.filterable(filters: { document: { present: 'true' } }) }.not_to raise_error
      expect(result.count).to eq(3)
      expect(FakeAttach.filterable_declarations.errors).to contain_exactly(
        "attachable: 'document' maps to unknown attachment 'document' on FakeAttach"
      )
    end
  end

  describe Filterable::ValueNormalization, '.normalize' do
    it 'passes booleans through for JSON body params' do
      expect(described_class.normalize(true)).to be(true)
      expect(described_class.normalize(false)).to be(false)
    end
  end

  describe 'inheritance' do
    it 'inherits the datable and sortable declarations in a subclass' do
      subclass = Class.new(MovementDetail)

      expect(subclass.datable_attribute_names[:value_date]).to eq(:value_date)
      expect(subclass.sortable_attribute_names[:value_date]).to eq(:value_date)
    end

    it 'filters through a subclass with the inherited declarations' do
      result = Class.new(MovementDetail).filterable(filters: { value_date: { after: '2026-02-01' } })

      expect(result.map(&:id)).to contain_exactly(february.id, march.id)
    end

    it 'does not leak subclass declarations into the parent' do
      Class.new(MovementDetail) { datable booked: :booking_date }

      expect(MovementDetail.datable_attribute_names).not_to have_key(:booked)
    end
  end

  describe Filterable::Rangeable, '.parse' do
    it 'passes an already-numeric value through untouched' do
      expect(described_class.parse(100)).to eq(100)
      expect(described_class.parse(99.5)).to eq(99.5)
    end

    it 'parses a zero-padded integer string in base ten, not octal' do
      expect(described_class.parse('010')).to eq(10)
    end
  end

  describe Filterable::Datable, '.parse' do
    it 'passes an already-parsed Date or Time through untouched' do
      date = Date.new(2026, 2, 1)
      time = Time.new(2026, 2, 1, 12)

      expect(described_class.parse(date)).to eq(date)
      expect(described_class.parse(time)).to eq(time)
    end
  end
end
