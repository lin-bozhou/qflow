# frozen_string_literal: true

module QFlow
  class RuleError < StandardError; end

  class DefinitionError < RuleError; end

  class UsageError < RuleError; end

  class FlowError < StandardError; end
end
