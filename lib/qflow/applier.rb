# frozen_string_literal: true

require_relative 'engine'

class QFlow::Applier
  # @param question_rule [QFlow::Rule]
  def initialize(question_rule)
    @engine = QFlow::Engine.new(question_rule)
  end

  # @param question_code [String, Symbol]
  # @param args [Hash]
  # @return [QFlow::Action]
  def apply(question_code, **args)
    @engine.run(question_code, **args)
  end
end
