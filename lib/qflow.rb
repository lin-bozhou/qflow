# frozen_string_literal: true

require_relative 'qflow/applier'
require_relative 'qflow/rule'

module QFlow
  # public API for creating question applier
  def self.use(question_rule)
    Applier.new(question_rule)
  end

  # public API for creating question rule
  def self.define(initial_questions = [], &)
    Rule.define(initial_questions, &)
  end
end
