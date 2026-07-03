# frozen_string_literal: true

# The initializer has already run in spec_helper; these specs assert the wiring.
RSpec.describe Filterable::Railtie do
  it 'is a Rails railtie' do
    expect(described_class.ancestors).to include(Rails::Railtie)
  end

  it 'registers the active_record initializer' do
    names = described_class.initializers.map(&:name)
    expect(names).to include('filterable.active_record')
  end

  describe 'auto-include into ActiveRecord::Base' do
    it 'exposes the filtering engine on every model without an explicit include' do
      expect(ActiveRecord::Base).to be < Filterable::Concern
      expect(ActiveRecord::Base).to respond_to(:filterable)
    end

    it 'exposes the datable, sortable, equatable and rangeable declaration DSL on every model' do
      expect(ActiveRecord::Base).to respond_to(:datable)
      expect(ActiveRecord::Base).to respond_to(:sortable)
      expect(ActiveRecord::Base).to respond_to(:equatable)
      expect(ActiveRecord::Base).to respond_to(:rangeable)
    end

    it 'leaves a model that declares nothing as a pass-through' do
      bare = Class.new(ActiveRecord::Base) { self.table_name = 'movement_details' }
      MovementDetail.create!(value_date: Date.new(2026, 1, 1))

      expect(bare.filterable(filters: { value_date: { after: '2030-01-01' } }).count).to eq(1)
    end
  end
end
