# frozen_string_literal: true

class QFlow::Action
  # @return [Array<String>]
  attr_reader :skip, :recover

  # @param skip [Array<Symbol>]
  # @param recover [Array<Symbol>]
  def initialize(skip: [], recover: [])
    @skip = skip.map(&:to_s).freeze
    @recover = recover.map(&:to_s).freeze
  end
end
