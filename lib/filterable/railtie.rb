# frozen_string_literal: true

module Filterable
  # Rails integration for +filterable+. Loaded only when +Rails::Railtie+ is
  # defined (see the guarded +require_relative+ in {file:lib/filterable.rb}).
  #
  # The single initializer hooks +ActiveSupport.on_load(:active_record)+ so the
  # filtering engine and every declaration concern are mixed into
  # +ActiveRecord::Base+ once — every model then exposes +filterable+ and the
  # +datable+ / +sortable+ / +equatable+ / +rangeable+ / +scopable+ /
  # +togglable+ declaration DSL without an explicit +include+. A model that
  # declares nothing keeps an empty whitelist, so +filterable+ is a no-op that
  # returns +all+.
  #
  # Outside Rails the railtie is never loaded; include the concerns manually.
  #
  # @api private
  class Railtie < Rails::Railtie
    initializer 'filterable.active_record' do
      ActiveSupport.on_load(:active_record) do
        include Filterable::Concern
        include Filterable::Concerns::Attachable
        include Filterable::Concerns::Datable
        include Filterable::Concerns::Equatable
        include Filterable::Concerns::Matchable
        include Filterable::Concerns::Rangeable
        include Filterable::Concerns::Scopable
        include Filterable::Concerns::Sortable
        include Filterable::Concerns::Togglable
      end
    end
  end
end
