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
      end
    end

    it 'maps a bare attribute onto its own column' do
      model.datable(:value_date).sortable(:value_date).equatable(:reference).rangeable(:gross_amount_cents)

      expect(model.datable_attribute_names[:value_date]).to eq(:value_date)
      expect(model.sortable_attribute_names[:value_date]).to eq(:value_date)
      expect(model.equatable_attribute_names[:reference]).to eq(:reference)
      expect(model.rangeable_attribute_names[:gross_amount_cents]).to eq(:gross_amount_cents)
    end

    it 'aliases a public name to a column through a hash' do
      model.datable(date: :value_date).sortable(amount: :gross_amount_cents).equatable(ref: :reference)
           .rangeable(amount: :gross_amount_cents)

      expect(model.datable_attribute_names[:date]).to eq(:value_date)
      expect(model.sortable_attribute_names[:amount]).to eq(:gross_amount_cents)
      expect(model.equatable_attribute_names[:ref]).to eq(:reference)
      expect(model.rangeable_attribute_names[:amount]).to eq(:gross_amount_cents)
    end

    it 'ignores an unsupported declaration' do
      model.datable(42).sortable(nil).equatable(3.14).rangeable(Object.new)

      expect(model.datable_attribute_names).to be_empty
      expect(model.sortable_attribute_names).to be_empty
      expect(model.equatable_attribute_names).to be_empty
      expect(model.rangeable_attribute_names).to be_empty
    end
  end

  describe Filterable::Equatable, '.normalize' do
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
