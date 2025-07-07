# frozen_string_literal: true

require_relative 'errors'

class QFlow::Transition
  # @param current_question [String, Symbol]
  # @param args_config [Array<Symbol>]
  # @param args [Hash]
  # @param allowed_targets [Array<Symbol>]
  def initialize(current_question, args_config, args, allowed_targets = [])
    @current_question = current_question.to_sym
    @args_config = args_config || []
    @args = args || {}
    @allowed_targets = allowed_targets || []
    @target = nil

    validate_args
    setup_args
  end

  # @param transitions_block [Proc]
  # @return [Symbol, nil]
  def calc(transitions_block)
    instance_exec(&transitions_block)
    @target
  end

  # @param question_code [String, Symbol]
  def target(question_code)
    if question_code.to_s.empty?
      raise ArgumentError, "Error: question '#{@current_question}' has defined a target but it is empty"
    end

    code_sym = question_code.to_sym

    if code_sym == @current_question
      raise ArgumentError,
            "Error: question '#{@current_question}' cannot target itself"
    end

    unless @allowed_targets.empty? || @allowed_targets.include?(code_sym)
      raise QFlow::UsageError,
            "Error: question '#{@current_question}' target '#{code_sym}' is not in defined targets: " \
            "#{@allowed_targets}"
    end

    @target = code_sym
  end

  %w[effects deps args targets].each do |method_name|
    define_method(method_name) do |*|
      raise QFlow::UsageError,
            "Error: '#{method_name}' should be called in the question definition block, not inside 'transitions'"
    end
  end

  private

  def validate_args
    return if @args_config.empty?

    missing_args = @args_config - @args.keys
    return unless missing_args.any?

    raise ArgumentError, "Error: question '#{@current_question}' missing parameters: #{missing_args.join(', ')}"
  end

  def setup_args
    @args_config.each do |arg|
      define_singleton_method(arg) do
        @args[arg]
      end
    end
  end
end
