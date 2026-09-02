# frozen_string_literal: true

require 'spec_helper'

# A datable column holding an instant is still asked about in days: a consumer sending
# `since=2026-03-01` means that day, not the midnight opening it. Read as an instant,
# such a bound dropped every record of the day it named but a midnight one.
RSpec.describe Filterable::Concerns::Datable, 'on a datetime column' do
  let!(:morning) { MovementDetail.create!(quoted_at: Time.utc(2026, 3, 1, 9, 0)) }
  let!(:evening) { MovementDetail.create!(quoted_at: Time.utc(2026, 3, 1, 17, 30)) }
  let!(:next_day) { MovementDetail.create!(quoted_at: Time.utc(2026, 3, 2, 9, 0)) }

  def filter(bounds)
    MovementDetail.where.not(quoted_at: nil).filterable(filters: { quoted_at: bounds })
  end

  describe 'a bound given as a bare day names the whole day' do
    it 'keeps every record of the day under a since ceiling' do
      expect(filter(since: '2026-03-01')).to contain_exactly(morning, evening)
    end

    it 'keeps every record of the day under a from/to range' do
      expect(filter(from: '2026-03-01', to: '2026-03-01')).to contain_exactly(morning, evening)
    end

    it 'excludes the whole day under a before floor' do
      expect(filter(before: '2026-03-02')).to contain_exactly(morning, evening)
    end

    it 'excludes the whole day under an after floor' do
      expect(filter(after: '2026-03-01')).to contain_exactly(next_day)
    end
  end

  describe 'a bound carrying an hour is honoured to the second' do
    it 'cuts inside the day on since' do
      expect(filter(since: '2026-03-01T12:00:00Z')).to contain_exactly(morning)
    end

    it 'cuts inside the day on after' do
      expect(filter(after: '2026-03-01T12:00:00Z')).to contain_exactly(evening, next_day)
    end

    it 'cuts inside the day on before' do
      expect(filter(before: '2026-03-01T12:00:00Z')).to contain_exactly(morning)
    end

    it 'cuts inside the day on a range' do
      expect(filter(from: '2026-03-01T12:00:00Z', to: '2026-03-02T12:00:00Z'))
        .to contain_exactly(evening, next_day)
    end
  end

  describe 'a date column is left as it was' do
    let!(:january) { MovementDetail.create!(value_date: Date.new(2026, 1, 1)) }
    let!(:february) { MovementDetail.create!(value_date: Date.new(2026, 2, 1)) }

    it 'keeps the bound inclusive on since' do
      result = MovementDetail.where.not(value_date: nil).filterable(filters: { value_date: { since: '2026-02-01' } })

      expect(result).to contain_exactly(january, february)
    end

    it 'keeps the bound exclusive on after' do
      result = MovementDetail.where.not(value_date: nil).filterable(filters: { value_date: { after: '2026-01-01' } })

      expect(result).to contain_exactly(february)
    end
  end
end
