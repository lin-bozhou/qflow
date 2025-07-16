# frozen_string_literal: true

require_relative 'errors'
require_relative 'action'
require_relative 'transition'

class QFlow::Engine
  # @param question_rule [QFlow::Rule]
  def initialize(question_rule)
    @question_rule = question_rule
    @effect_mapping = {}

    build_effect_mapping!
  end

  # @param question_code [String, Symbol]
  # @param args [Hash]
  # @return [QFlow::Action]
  def run(question_code, **args)
    raise ArgumentError, 'Error: question code cannot be empty' if question_code.to_s.empty?

    return QFlow::Action.new if @question_rule.nil? || @question_rule.configs.empty?

    code = question_code.to_sym
    config = @question_rule.configs[code]
    return QFlow::Action.new unless config

    next_question = calc_next_question(code, config, args)
    skip_questions = calc_skip_questions(code, next_question)
    recover_questions = calc_recover_questions(next_question, skip_questions, config[:effects], config[:targets])

    QFlow::Action.new(skip: skip_questions, recover: recover_questions)
  end

  def build_effect_mapping!
    @effect_mapping = {}
    return if @question_rule.nil? || @question_rule.configs.empty?

    @question_rule.configs.each do |code, config|
      next unless config[:deps]

      config[:deps].each do |dep|
        @effect_mapping[dep] ||= []
        @effect_mapping[dep] << code unless @effect_mapping[dep].include?(code)
      end
    end
  end

  private

  # @param question_code [Symbol]
  # @param question_config [Hash]
  # @param args [Hash]
  # @return [Symbol, nil]
  def calc_next_question(question_code, question_config, args)
    transitions_block = question_config[:transitions]
    args_config = question_config[:args]
    targets_config = question_config[:targets]
    return nil unless transitions_block

    trans = QFlow::Transition.new(question_code, args_config, args, targets_config)
    trans.calc(transitions_block)
  end

  # @param question_code [Symbol]
  # @param next_question [Symbol, nil]
  # @return [Array<Symbol>]
  def calc_skip_questions(question_code, next_question)
    return [] unless next_question

    codes = @question_rule.codes
    current_idx = codes.index(question_code)
    next_idx = codes.index(next_question)
    if current_idx.nil? || next_idx.nil? || current_idx >= next_idx
      raise QFlow::FlowError,
            "Error: invalid question flow: current=#{question_code}, next=#{next_question}"
    end

    codes[(current_idx + 1)...next_idx]
  end

  # @param next_question [Symbol, nil]
  # @param skip_questions [Array<Symbol>]
  # @param effects [Array<Symbol>]
  # @param targets [Array<Symbol>]
  # @return [Array<Symbol>]
  def calc_recover_questions(next_question, skip_questions, effects, targets)
    range_recover = calc_range_recover(next_question, targets)
    dep_recover = []
    effects.each do |effect|
      affected_questions = @effect_mapping[effect]
      dep_recover.concat(affected_questions) if affected_questions
    end
    dep_recover = dep_recover.uniq

    all_recover = (range_recover + dep_recover).uniq
    all_recover - skip_questions
  end

  # @param next_question [Symbol, nil]
  # @param targets [Array<Symbol>]
  # @return [Array<Symbol>]
  def calc_range_recover(next_question, targets)
    return [] if next_question.nil? || targets.empty?

    codes = @question_rule.codes
    next_idx = codes.index(next_question)
    last_idx = targets.map { codes.index(_1) }.compact.max

    return [] if next_idx.nil? || last_idx.nil? || next_idx > last_idx

    codes[next_idx...last_idx]
  end
end
