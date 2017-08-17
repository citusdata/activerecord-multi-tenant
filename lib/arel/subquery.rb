# frozen_string_literal: true

# Allow creation of a subquery that acts like an Arel::Table so it can be used in joins
module Arel
  class Subquery < Table
    attr_accessor :data_source

    def initialize(data_source, as:, type_caster: nil)
      super(as, type_caster: type_caster)
      @data_source = data_source
    end
  end
end
