# frozen_string_literal: true

require_relative 'qflow/applier'
require_relative 'qflow/rule'

module QFlow
  # public API for creating question applier
  # @param question_rule [QFlow::Rule]
  # @return [QFlow::Applier]
  def self.use(question_rule)
    Applier.new(question_rule)
  end

  # public API for creating question rule
  # @param initial_questions [Array<String, Symbol>]
  # @param &block [Proc]
  # @return [QFlow::Rule]
  def self.define(initial_questions = [], &)
    Rule.define(initial_questions, &)
  end
end
