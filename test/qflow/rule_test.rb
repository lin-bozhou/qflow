# frozen_string_literal: true

require_relative '../test_helper'

class RuleTest < Minitest::Test
  def test_define_simple_question
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q2 do
        effects :flag3, :flag4
      end

      question :q1 do
        effects :flag1, :flag2
        deps :flag3, :flag4
        args :a1, :a2
        targets :q2, :q3, :q4

        transitions do
          case a1
          when true
            target :q2
          when false
            target a2? ? :q3 : :q4
          end
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[flag1 flag2], config[:effects]
    assert_equal %i[flag3 flag4], config[:deps]
    assert_equal %i[a1 a2], config[:args]
    assert_equal %i[q2 q3 q4], config[:targets]
    refute_nil config[:transitions]
    assert_equal %i[q1 q2 q3 q4], rule.codes
  end

  def test_question_has_transitions_but_no_predefined_answers
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q2 do
        effects :flag2
      end

      question :q1 do
        effects :flag1
        deps :flag2
        args :a1
        targets :q2, :q3

        transitions do
          target a1 ? :q2 : :q3
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [:flag1], config[:effects]
    assert_equal [:flag2], config[:deps]
    assert_equal [:a1], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions]
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
    assert_empty config[:effects]
    assert_empty config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]
    assert_equal [:q1], rule.codes
  end

  def test_multiple_questions_with_different_configurations
    rule = QFlow.define do
      question :q1 do
        effects :flag1, :flag2
        deps :flag3, :flag4
        args :a1, :a2
        targets :q2, :q3

        transitions do
          case a1
          when true
            target :q2
          when false
            target :q3
          end
        end
      end

      question :q2 do
        effects :flag3
      end

      question :q3 do
        deps :flag3
      end

      question :q4 do
        effects :flag4
        deps :flag3
      end

      question :q5 do
        # empty
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[flag1 flag2], config[:effects]
    assert_equal %i[flag3 flag4], config[:deps]
    assert_equal %i[a1 a2], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions]

    config = rule.configs[:q2]
    refute_nil config
    assert_equal [:flag3], config[:effects]
    assert_empty config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]

    config = rule.configs[:q3]
    refute_nil config
    assert_empty config[:effects]
    assert_equal [:flag3], config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]

    config = rule.configs[:q4]
    refute_nil config
    assert_equal [:flag4], config[:effects]
    assert_equal [:flag3], config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]

    config = rule.configs[:q5]
    refute_nil config
    assert_empty config[:effects]
    assert_empty config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]

    assert_equal %i[q1 q2 q3 q4 q5], rule.codes
  end

  def test_clear_rules
    rule = QFlow.define
    rule.instance_eval do
      question :q1 do
        args :a1
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
        args :a1
        targets :q2, :q3
        transitions do
          case a1
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
    assert_empty config[:effects]
    assert_empty config[:deps]
    assert_equal [:a1], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions]

    config = rule.configs[:q2]
    refute_nil config
    assert_empty config[:effects]
    assert_empty config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]

    config = rule.configs[:q3]
    refute_nil config
    assert_empty config[:effects]
    assert_empty config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]

    assert_equal %i[q1 q2 q3], rule.codes
  end

  def test_question_has_args_but_missing_transitions
    error = assert_raises QFlow::DefinitionError do
      QFlow.define do
        question :q1 do
          args :a1
          effects :flag1
        end
      end
    end

    assert_match(/Error: question 'q1' has args but no transitions block defined/, error.message)
  end

  def test_empty_question_code
    error = assert_raises ArgumentError do
      QFlow.define do
        question '' do
          args :a1
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
          args :a1
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
          effects :flag1
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
          args :a1
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
        args :a1
        effects :flag1
        targets :q2, :q3
        transitions do
          case a1
          when 'yes'
            target :q2
          when 'no'
            target :q3
          end
        end
      end

      question :q4 do
        effects :flag2
        deps :flag1
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [:flag1], config[:effects]
    assert_empty config[:deps]
    assert_equal [:a1], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions]

    config = rule.configs[:q4]
    refute_nil config
    assert_equal [:flag2], config[:effects]
    assert_equal [:flag1], config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]

    assert_nil rule.configs[:q2]
    assert_nil rule.configs[:q3]
    assert_nil rule.configs[:q5]

    assert_equal %i[q1 q2 q3 q4 q5], rule.codes
  end

  def test_define_without_initial_question_codes
    rule = QFlow.define do
      question :q1 do
        args :a1
        effects :flag1
        targets :q2
        transitions do
          target :q2
        end
      end

      question :q2 do
        effects :flag2
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [:flag1], config[:effects]
    assert_empty config[:deps]
    assert_equal [:a1], config[:args]
    assert_equal [:q2], config[:targets]
    refute_nil config[:transitions]

    config = rule.configs[:q2]
    refute_nil config
    assert_equal [:flag2], config[:effects]
    assert_empty config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]

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
        args :a1
        targets :q3
        transitions do
          target :q3
        end
      end

      question :q5 do
        effects :flag1
      end
    end

    config = rule.configs[:q2]
    refute_nil config
    assert_empty config[:effects]
    assert_empty config[:deps]
    assert_equal [:a1], config[:args]
    assert_equal [:q3], config[:targets]
    refute_nil config[:transitions]

    config = rule.configs[:q5]
    refute_nil config
    assert_equal [:flag1], config[:effects]
    assert_empty config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]

    assert_nil rule.configs[:q1]
    assert_nil rule.configs[:q3]
    assert_nil rule.configs[:q4]

    assert_equal %i[q1 q2 q3 q4 q5], rule.codes
  end

  def test_target_not_in_targets_raises_error
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        args :a1
        targets :q2, :q3
        transitions do
          target :q4 # not in targets
        end
      end
    end

    applier = QFlow.use(rule)
    error = assert_raises QFlow::UsageError do
      applier.apply(:q1, a1: 'yes')
    end
    assert_match(/Error: question 'q1' target 'q4' is not in defined targets/, error.message)
  end

  def test_params_and_targets_functions
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q2 do
        effects :flag2
      end

      question :q1 do
        args :a1, :a2
        targets :q2, :q3, :q4
        effects :flag1
        deps :flag2
        transitions do
          target a1 > a2 ? :q2 : :q3
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [:flag1], config[:effects]
    assert_equal [:flag2], config[:deps]
    assert_equal %i[a1 a2], config[:args]
    assert_equal %i[q2 q3 q4], config[:targets]
  end

  def test_params_with_transitions_should_succeed
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        args :a1
        targets :q2, :q3
        transitions do
          target a1 ? :q2 : :q3
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_empty config[:effects]
    assert_empty config[:deps]
    assert_equal [:a1], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions]
  end

  def test_targets_with_transitions_should_succeed
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        args :a1
        targets :q2, :q3
        transitions do
          target a1 == 'yes' ? :q2 : :q3
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_empty config[:effects]
    assert_empty config[:deps]
    assert_equal [:a1], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions]
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
          args :a1
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
        args :a1
        targets :q2, :q3 # both in question codes
        transitions do
          target a1 ? :q2 : :q3
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_empty config[:effects]
    assert_empty config[:deps]
    assert_equal [:a1], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions]
  end

  def test_deps_and_effects_overlap_should_fail
    error = assert_raises QFlow::DefinitionError do
      QFlow.define(%w[q1 q2]) do
        question :q1 do
          args :a1
          effects :flag1, :flag2
          deps :flag1, :flag3 # flag1 overlaps with effects
          targets :q2
          transitions do
            target :q2
          end
        end
      end
    end
    assert_match(/Error: question 'q1' has deps that overlap with its effects \[:flag1\]/, error.message)
  end

  def test_deps_and_effects_no_overlap_should_succeed
    rule = QFlow.define(%w[q1 q2]) do
      question :q2 do
        effects :flag3, :flag4
      end

      question :q1 do
        args :a1
        effects :flag1, :flag2
        deps :flag3, :flag4 # no overlap with effects
        targets :q2
        transitions do
          target :q2
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[flag1 flag2], config[:effects]
    assert_equal %i[flag3 flag4], config[:deps]
    assert_equal %i[a1], config[:args]
    assert_equal %i[q2], config[:targets]
    refute_nil config[:transitions]
  end

  def test_deps_not_defined_in_effects_should_fail
    error = assert_raises QFlow::DefinitionError do
      QFlow.define(%w[q1 q2]) do
        question :q1 do
          args :a1
          effects :flag1
          deps :undefined_flag # not defined in any effects
          targets :q2
          transitions do
            target :q2
          end
        end
      end
    end
    assert_match(/Error: deps \[:undefined_flag\] are not defined in effects/, error.message)
  end

  def test_deps_all_defined_in_effects_should_succeed
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q2 do
        effects :flag2, :flag3
      end

      question :q1 do
        args :a1
        effects :flag1
        deps :flag2, :flag3 # both defined in q2's effects
        targets :q2
        transitions do
          target :q2
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal [:flag1], config[:effects]
    assert_equal %i[flag2 flag3], config[:deps]
    assert_equal %i[a1], config[:args]
    assert_equal %i[q2], config[:targets]
    refute_nil config[:transitions]
  end

  def test_multiple_calls_should_merge_without_duplicates
    rule = QFlow.define(%w[q1 q2]) do
      question :q1 do
        args :a1, :a2
        args :a2, :a3 # a2 is duplicate, should be ignored
        args :a1, :a4 # a1 is duplicate, should be ignored

        effects :flag1, :flag2
        effects :flag2, :flag3 # flag2 is duplicate, should be ignored
        effects :flag1, :flag4 # flag1 is duplicate, should be ignored

        targets :q2
        targets :q2 # duplicate, should be ignored

        transitions do
          target :q2
        end
      end

      question :q2 do
        deps :flag1, :flag2
        deps :flag2, :flag3 # flag2 is duplicate, should be ignored
        deps :flag1, :flag4 # flag1 is duplicate, should be ignored
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[flag1 flag2 flag3 flag4], config[:effects]
    assert_empty config[:deps]
    assert_equal %i[a1 a2 a3 a4], config[:args]
    assert_equal %i[q2], config[:targets]
    refute_nil config[:transitions]

    config = rule.configs[:q2]
    refute_nil config
    assert_empty config[:effects]
    assert_equal %i[flag1 flag2 flag3 flag4], config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]
  end

  def test_incremental_building_with_multiple_calls
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        args :a1
        effects :flag1
        targets :q2

        # add more
        args :a2
        effects :flag2
        targets :q3

        transitions do
          case a1
          when 'option1'
            target :q2
          when 'option2'
            target :q3
          end
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[flag1 flag2], config[:effects]
    assert_empty config[:deps]
    assert_equal %i[a1 a2], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions]
  end

  def test_empty_calls_should_not_affect_existing_values
    rule = QFlow.define(%w[q1 q2]) do
      question :q1 do
        args :a1, :a2
        effects :flag1, :flag2
        targets :q2

        # empty calls should not change anything
        args
        effects
        deps
        targets

        transitions do
          target :q2
        end
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[flag1 flag2], config[:effects]
    assert_empty config[:deps]
    assert_equal %i[a1 a2], config[:args]
    assert_equal %i[q2], config[:targets]
    refute_nil config[:transitions]
  end

  def test_all_string_parameters
    rule = QFlow.define(%w[q1 q2 q3]) do
      question 'q1' do
        args 'a1', 'a2'
        effects 'flag1', 'flag2'
        targets 'q2', 'q3'

        transitions do
          target 'q2'
        end
      end

      question 'q2' do
        deps 'flag1', 'flag2'
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[flag1 flag2], config[:effects]
    assert_empty config[:deps]
    assert_equal %i[a1 a2], config[:args]
    assert_equal %i[q2 q3], config[:targets]
    refute_nil config[:transitions]

    config = rule.configs[:q2]
    refute_nil config
    assert_empty config[:effects]
    assert_equal %i[flag1 flag2], config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]

    assert_equal %i[q1 q2 q3], rule.codes
  end

  def test_mixed_string_and_symbol_parameters
    rule = QFlow.define(['q1', :q2, 'q3', :q4]) do
      question 'q1' do
        args 'a1', :a2, 'a3'
        effects :flag1, 'flag2', :flag3
        targets 'q2', :q3, 'q4'

        transitions do
          target :q2
        end
      end

      question :q2 do
        deps 'flag1', :flag2, 'flag3'
      end
    end

    config = rule.configs[:q1]
    refute_nil config
    assert_equal %i[flag1 flag2 flag3], config[:effects]
    assert_empty config[:deps]
    assert_equal %i[a1 a2 a3], config[:args]
    assert_equal %i[q2 q3 q4], config[:targets]
    refute_nil config[:transitions]

    config = rule.configs[:q2]
    refute_nil config
    assert_empty config[:effects]
    assert_equal %i[flag1 flag2 flag3], config[:deps]
    assert_empty config[:args]
    assert_empty config[:targets]
    assert_nil config[:transitions]

    assert_equal %i[q1 q2 q3 q4], rule.codes
  end
end
