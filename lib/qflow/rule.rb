# frozen_string_literal: true

require_relative 'errors'

class QFlow::Rule
  # @param initial_questions [Array<String, Symbol>]
  def initialize(initial_questions = [])
    @rules = {}
    @question_codes = self.class.normalize_symbols(initial_questions)
  end

  # @param initial_questions [Array<String, Symbol>]
  # @param &block [Proc]
  # @return [QFlow::Rule]
  def self.define(initial_questions = [], &)
    new(initial_questions).tap do |rule|
      rule.instance_eval(&) if block_given?
      rule.send(:validate_targets!)
      rule.send(:validate_deps!)
    end
  end

  # @return [Hash]
  def configs
    @rules
  end

  # @return [Array<String>]
  def codes
    @question_codes
  end

  def clear!
    @rules = {}
    @question_codes = []
  end

  # @param question_code [String, Symbol]
  # @param &block [Proc]
  def question(question_code, &)
    raise ArgumentError, 'Error: question code cannot be empty' if question_code.to_s.empty?
    raise ArgumentError, 'Error: block is required for question definition' unless block_given?

    code = question_code.to_sym
    @rules[code] = Builder.new(code, &).build
    @question_codes << code unless @question_codes.include?(code)
  end

  # @param values [Array<String, Symbol, nil>]
  # @return [Array<Symbol>]
  def self.normalize_symbols(values)
    values.filter_map do |value|
      str = value.to_s
      str.to_sym unless str.empty?
    end.uniq
  end

  private

  def validate_targets!
    all_targets = @rules.values.flat_map { _1[:targets] }.uniq
    invalid_targets = all_targets - @question_codes

    return if invalid_targets.empty?

    raise QFlow::DefinitionError,
          "Error: targets #{invalid_targets.inspect} are not defined in question codes #{@question_codes.inspect}"
  end

  def validate_deps!
    all_effects = @rules.values.flat_map { _1[:effects] }.uniq
    all_deps = @rules.values.flat_map { _1[:deps] }.uniq
    invalid_deps = all_deps - all_effects

    return if invalid_deps.empty?

    raise QFlow::DefinitionError,
          "Error: deps #{invalid_deps.inspect} are not defined in effects #{all_effects}"
  end

  class Builder
    # @param question_code [Symbol]
    # @param &block [Proc]
    def initialize(question_code, &)
      @current_question = question_code
      @effects = []
      @deps = []
      @args = []
      @targets = []
      @transitions = nil

      instance_eval(&) if block_given?
    end

    # @param effect_vars [Array<String, Symbol>]
    def effects(*effect_vars)
      @effects |= QFlow::Rule.normalize_symbols(effect_vars)
    end

    # @param dep_vars [Array<String, Symbol>]
    def deps(*dep_vars)
      @deps |= QFlow::Rule.normalize_symbols(dep_vars)
    end

    # @param arg_vars [Array<String, Symbol>]
    def args(*arg_vars)
      @args |= QFlow::Rule.normalize_symbols(arg_vars)
    end

    # @param target_list [Array<String, Symbol>]
    def targets(*target_list)
      @targets |= QFlow::Rule.normalize_symbols(target_list)
    end

    # @param &block [Proc]
    def transitions(&block)
      raise QFlow::DefinitionError, "Error: 'transitions' requires a block" unless block_given?

      @transitions = block
    end

    def target(*)
      raise QFlow::UsageError,
            "Error: 'target' should be called inside a 'transitions' block, not directly in the question definition"
    end

    # @return [Hash]
    def build
      validate_config!

      {
        effects: @effects,
        deps: @deps,
        args: @args,
        targets: @targets,
        transitions: @transitions
      }
    end

    private

    def validate_config!
      # if args exists, transitions must be defined
      if @args.any? && @transitions.nil?
        raise QFlow::DefinitionError,
              "Error: question '#{@current_question}' has args but no transitions block defined"
      end

      # if targets exists, transitions must be defined
      if @targets.any? && @transitions.nil?
        raise QFlow::DefinitionError,
              "Error: question '#{@current_question}' has targets but no transitions block defined"
      end

      # if transitions exists, must have args defined
      if @transitions && @args.empty?
        raise QFlow::DefinitionError,
              "Error: question '#{@current_question}' has transitions but no args defined"
      end

      # if transitions exists, must have targets defined
      if @transitions && @targets.empty?
        raise QFlow::DefinitionError,
              "Error: question '#{@current_question}' has transitions but no targets defined"
      end

      # if targets are defined, they must not include the current question
      if @targets.include?(@current_question)
        raise QFlow::DefinitionError,
              "Error: question '#{@current_question}' cannot target itself in its own targets list"
      end

      # deps must not overlap with effects
      return unless @deps.intersect?(@effects)

      raise QFlow::DefinitionError,
            "Error: question '#{@current_question}' has deps that overlap with its effects #{@deps & @effects}"
    end
  end
end
