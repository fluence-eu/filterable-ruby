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

  describe Filterable::Datable, '.parse' do
    it 'passes an already-parsed Date or Time through untouched' do
      date = Date.new(2026, 2, 1)
      time = Time.new(2026, 2, 1, 12)

      expect(described_class.parse(date)).to eq(date)
      expect(described_class.parse(time)).to eq(time)
    end
  end
end
