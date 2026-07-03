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

    it 'accepts ActionController::Parameters from a controller' do
      params = ActionController::Parameters.new(filters: { value_date: { after: '2026-02-01' } })
      expect(MovementDetail.filterable(params)).to contain_exactly(february, march)
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
      end
    end

    it 'maps a bare attribute onto its own column' do
      model.datable(:value_date).sortable(:value_date)

      expect(model.datable_attribute_names[:value_date]).to eq(:value_date)
      expect(model.sortable_attribute_names[:value_date]).to eq(:value_date)
    end

    it 'aliases a public name to a column through a hash' do
      model.datable(date: :value_date).sortable(amount: :gross_amount_cents)

      expect(model.datable_attribute_names[:date]).to eq(:value_date)
      expect(model.sortable_attribute_names[:amount]).to eq(:gross_amount_cents)
    end

    it 'ignores an unsupported declaration' do
      model.datable(42).sortable(nil)

      expect(model.datable_attribute_names).to be_empty
      expect(model.sortable_attribute_names).to be_empty
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
