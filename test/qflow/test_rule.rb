# frozen_string_literal: true

require_relative '../test_helper'

class TestRule < Minitest::Test
  def test_define_simple_question
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q1 do
        effects :e1, :e2
        deps :d1, :d2
        args :answer, :a1
        targets :q2, :q3, :q4

        transitions do
          case answer
          when true
            target :q2
          when false
            target a1? ? :q3 : :q4
          end
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[e1 e2], config[:effects]
    assert_equal %i[d1 d2], config[:deps]
    assert_equal %i[answer a1], config[:args]
    assert_equal %i[q2 q3 q4], config[:targets]
    refute_nil config[:transitions_block]
    assert_equal %i[q1 q2 q3 q4], rule.codes
  end

  def test_question_has_transitions_but_no_predefined_answers
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        effects :e1
        deps :condition_dep
        args :condition
        targets :q2, :q3

        transitions do
          target condition ? :q2 : :q3
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [:e1], config[:effects]
    assert_equal [:condition_dep], config[:deps]
    assert_equal [:condition], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions_block]
    assert_equal %i[q1 q2 q3], rule.codes
  end

  def test_empty_question_block
    rule = QFlow.define do
      question :q1 do
        # empty
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [], config[:effects]
    assert_equal [], config[:deps]
    assert_equal [], config[:args]
    assert_equal [], config[:targets]
    assert_nil config[:transitions_block]
    assert_equal [:q1], rule.codes
  end

  def test_multiple_questions_with_different_configurations
    rule = QFlow.define do
      question :q1 do
        effects :e1, :e2
        deps :d1, :d2
        args :answer, :user_age
        targets :q2, :q3

        transitions do
          case answer
          when true
            target :q2
          when false
            target :q3
          end
        end
      end

      question :q2 do
        effects :e3
      end

      question :q3 do
        deps :d3
      end

      question :q4 do
        effects :e4
        deps :d4
      end

      question :q5 do
        # empty
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[e1 e2], config[:effects]
    assert_equal %i[d1 d2], config[:deps]
    assert_equal %i[answer user_age], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions_block]

    config = rule.configs[:q2]
    refute_nil config
    assert_equal [:e3], config[:effects]
    assert_equal [], config[:deps]
    assert_equal [], config[:args]
    assert_equal [], config[:targets]
    assert_nil config[:transitions_block]

    config = rule.configs[:q3]
    refute_nil config
    assert_equal [], config[:effects]
    assert_equal [:d3], config[:deps]
    assert_equal [], config[:args]
    assert_equal [], config[:targets]
    assert_nil config[:transitions_block]

    config = rule.configs[:q4]
    refute_nil config
    assert_equal [:e4], config[:effects]
    assert_equal [:d4], config[:deps]
    assert_equal [], config[:args]
    assert_equal [], config[:targets]
    assert_nil config[:transitions_block]

    config = rule.configs[:q5]
    refute_nil config
    assert_equal [], config[:effects]
    assert_equal [], config[:deps]
    assert_equal [], config[:args]
    assert_equal [], config[:targets]
    assert_nil config[:transitions_block]

    assert_equal %i[q1 q2 q3 q4 q5], rule.codes
  end

  def test_clear_rules
    rule = QFlow.define
    rule.instance_eval do
      question :q1 do
        args :answer
        targets :q2
        transitions do
          target :q2
        end
      end
    end

    refute_empty rule.configs
    rule.clear!
    assert_empty rule.configs
    assert_empty rule.codes
  end

  def test_empty_rule
    rule = QFlow.define
    assert_empty rule.configs
    assert_empty rule.codes
  end

  def test_mixed_empty_and_normal_questions
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        args :answer
        targets :q2, :q3
        transitions do
          case answer
          when 'yes'
            target :q2
          when 'no'
            target :q3
          end
        end
      end

      question :q2 do
        # empty
      end

      question :q3 do
        # empty
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [], config[:effects]
    assert_equal [], config[:deps]
    assert_equal [:answer], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions_block]

    config = rule.configs[:q2]
    refute_nil config
    assert_equal [], config[:effects]
    assert_equal [], config[:deps]
    assert_equal [], config[:args]
    assert_equal [], config[:targets]
    assert_nil config[:transitions_block]

    config = rule.configs[:q3]
    refute_nil config
    assert_equal [], config[:effects]
    assert_equal [], config[:deps]
    assert_equal [], config[:args]
    assert_equal [], config[:targets]
    assert_nil config[:transitions_block]

    assert_equal %i[q1 q2 q3], rule.codes
  end

  def test_question_has_args_but_missing_transitions
    error = assert_raises QFlow::DefinitionError do
      QFlow.define do
        question :q1 do
          args :answer
          effects :e1
        end
      end
    end

    assert_match(/Error: question 'q1' has args but no transitions block defined/, error.message)
  end

  def test_empty_question_code
    error = assert_raises ArgumentError do
      QFlow.define do
        question '' do
          args :answer
        end
      end
    end
    assert_match(/Error: question code cannot be empty/, error.message)
  end

  def test_target_in_question_block
    error = assert_raises QFlow::UsageError do
      QFlow.define do
        question :q1 do
          target :q2
        end
      end
    end
    assert_match(/Error: 'target' should be called inside a 'transitions' block/, error.message)
  end

  def test_transitions_without_block
    error = assert_raises QFlow::DefinitionError do
      QFlow.define do
        question :q1 do
          args :answer
          targets :q2
          transitions
        end
      end
    end
    assert_match(/Error: 'transitions' requires a block/, error.message)
  end

  def test_transitions_without_args
    error = assert_raises QFlow::DefinitionError do
      QFlow.define do
        question :q1 do
          effects :e1
          transitions do
            target :q2
          end
        end
      end
    end
    assert_match(/Error: question 'q1' has transitions but no args defined/, error.message)
  end

  def test_transitions_without_targets
    error = assert_raises QFlow::DefinitionError do
      QFlow.define do
        question :q1 do
          args :answer
          transitions do
            target :q2
          end
        end
      end
    end
    assert_match(/Error: question 'q1' has transitions but no targets defined/, error.message)
  end

  def test_define_with_initial_question_codes
    rule = QFlow.define(%w[q1 q2 q3 q4 q5]) do
      question :q1 do
        args :answer
        effects :e1
        targets :q2, :q3
        transitions do
          case answer
          when 'yes'
            target :q2
          when 'no'
            target :q3
          end
        end
      end

      question :q4 do
        effects :e2
        deps :d1
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [:e1], config[:effects]
    assert_equal [], config[:deps]
    assert_equal [:answer], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions_block]

    config = rule.configs[:q4]
    refute_nil config
    assert_equal [:e2], config[:effects]
    assert_equal [:d1], config[:deps]
    assert_equal [], config[:args]
    assert_equal [], config[:targets]
    assert_nil config[:transitions_block]

    assert_nil rule.configs[:q2]
    assert_nil rule.configs[:q3]
    assert_nil rule.configs[:q5]

    assert_equal %i[q1 q2 q3 q4 q5], rule.codes
  end

  def test_define_without_initial_question_codes
    rule = QFlow.define do
      question :q1 do
        args :answer
        effects :e1
        targets :q2
        transitions do
          target :q2
        end
      end

      question :q2 do
        effects :e2
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [:e1], config[:effects]
    assert_equal [], config[:deps]
    assert_equal [:answer], config[:args]
    assert_equal [:q2], config[:targets]
    refute_nil config[:transitions_block]

    config = rule.configs[:q2]
    refute_nil config
    assert_equal [:e2], config[:effects]
    assert_equal [], config[:deps]
    assert_equal [], config[:args]
    assert_equal [], config[:targets]
    assert_nil config[:transitions_block]

    assert_equal %i[q1 q2], rule.codes
  end

  def test_define_with_initial_codes_but_empty_block
    rule = QFlow.define(%w[q1 q2 q3]) do
      # empty
    end

    assert_nil rule.configs[:q1]
    assert_nil rule.configs[:q2]
    assert_nil rule.configs[:q3]

    assert_equal %i[q1 q2 q3], rule.codes
  end

  def test_define_with_mixed_initial_and_defined_questions
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q2 do
        args :answer
        targets :q3
        transitions do
          target :q3
        end
      end

      question :q5 do
        effects :e1
      end
    end

    config = rule.configs[:q2]
    refute_nil config
    assert_equal [], config[:effects]
    assert_equal [], config[:deps]
    assert_equal [:answer], config[:args]
    assert_equal [:q3], config[:targets]
    refute_nil config[:transitions_block]

    config = rule.configs[:q5]
    refute_nil config
    assert_equal [:e1], config[:effects]
    assert_equal [], config[:deps]
    assert_equal [], config[:args]
    assert_equal [], config[:targets]
    assert_nil config[:transitions_block]

    assert_nil rule.configs[:q1]
    assert_nil rule.configs[:q3]
    assert_nil rule.configs[:q4]

    assert_equal %i[q1 q2 q3 q4 q5], rule.codes
  end

  def test_target_not_in_targets_raises_error
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        args :answer
        targets :q2, :q3
        transitions do
          target :q4 # not in targets
        end
      end
    end

    applier = QFlow.use(rule)
    error = assert_raises QFlow::UsageError do
      applier.apply(:q1, answer: 'yes')
    end
    assert_match(/Error: question 'q1' target 'q4' is not in defined targets/, error.message)
  end

  def test_params_and_targets_functions
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q1 do
        args :param1, :param2
        targets :q2, :q3, :q4
        effects :e1
        deps :d1
        transitions do
          target param1 > param2 ? :q2 : :q3
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[param1 param2], config[:args]
    assert_equal %i[q2 q3 q4], config[:targets]
    assert_equal [:e1], config[:effects]
    assert_equal [:d1], config[:deps]
  end

  def test_params_with_transitions_should_succeed
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        args :condition
        targets :q2, :q3
        transitions do
          target condition ? :q2 : :q3
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [:condition], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions_block]
  end

  def test_targets_with_transitions_should_succeed
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        args :answer
        targets :q2, :q3
        transitions do
          target answer == 'yes' ? :q2 : :q3
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [:answer], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions_block]
  end

  def test_question_without_block
    error = assert_raises ArgumentError do
      QFlow.define do
        question :q1
      end
    end
    assert_equal 'Error: block is required for question definition', error.message
  end

  def test_targets_not_in_question_codes_should_fail
    error = assert_raises QFlow::DefinitionError do
      QFlow.define(%w[q1 q2]) do
        question :q1 do
          args :answer
          targets :q2, :q3 # q3 not in question codes
          transitions do
            target :q2
          end
        end
      end
    end
    assert_match(/Error: targets.*are not defined in question codes/, error.message)
  end

  def test_targets_all_in_question_codes_should_succeed
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        args :answer
        targets :q2, :q3 # both in question codes
        transitions do
          target answer ? :q2 : :q3
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[q2 q3], config[:targets]
  end
end
