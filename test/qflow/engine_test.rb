# frozen_string_literal: true

require_relative '../test_helper'

class EngineTest < Minitest::Test
  def test_basic_question_transitions
    rule = QFlow.define(%i[q1 q2 q3 q4]) do
      question :q1 do
        args :a1
        targets :q3, :q4
        transitions do
          case a1
          in 'yes'
            target :q3
          in 'no'
            target :q4
          end
        end
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: 'yes')
    assert_equal %w[q2], action.skip
    assert_equal %w[q3], action.recover

    action = applier.apply(:q1, a1: 'no')
    assert_equal %w[q2 q3], action.skip
    assert_empty action.recover
  end

  def test_question_with_dependencies
    rule = QFlow.define(%i[q1 q2 q3 q4 q5]) do
      question :q1 do
        args :a1, :a2
        effects :flag1
        targets :q3, :q4, :q5

        transitions do
          case a1
          in 'option1'
            target a2 ? :q3 : :q4
          in 'option2'
            target :q5
          end
        end
      end

      question :q2 do
        deps :flag1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: 'option1', a2: true)
    assert_equal %w[q2], action.skip
    assert_equal %w[q3 q4], action.recover

    action = applier.apply(:q1, a1: 'option1', a2: false)
    assert_equal %w[q2 q3], action.skip
    assert_equal %w[q4], action.recover

    action = applier.apply(:q1, a1: 'option2', a2: true)
    assert_equal %w[q2 q3 q4], action.skip
    assert_empty action.recover
  end

  def test_question_with_effects_and_recovery
    rule = QFlow.define(%i[q1 q2 q3 q4]) do
      question :q1 do
        args :a1
        effects :flag1
        targets :q3, :q4

        transitions do
          case a1
          in true
            target :q3
          in false
            target :q4
          end
        end
      end

      question :q2 do
        deps :flag1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: true)
    assert_equal %w[q2], action.skip
    assert_equal %w[q3], action.recover

    action = applier.apply(:q1, a1: false)
    assert_equal %w[q2 q3], action.skip
    assert_empty action.recover
  end

  def test_transitions_without_predefined_answer_values
    rule = QFlow.define(%i[q1 q2 q3 q4]) do
      question :q1 do
        effects :flag1
        args :a1
        targets :q3, :q4
        transitions do
          target a1 ? :q3 : :q4
        end
      end

      question :q2 do
        deps :flag1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: true)
    assert_equal %w[q2], action.skip
    assert_equal %w[q3], action.recover
  end

  def test_transitions_with_complex_dependencies
    rule = QFlow.define(%i[q1 q2 q3 q4 q5 q6]) do
      question :q1 do
        args :a1, :a2, :a3, :a4
        effects :flag1
        targets :q3, :q4, :q5, :q6

        transitions do
          case a1
          in 'a'
            if a2 && a3
              target :q3
            elsif a2
              target :q4
            else
              target :q5
            end
          in 'b'
            target a4 > 50 ? :q3 : :q6
          in 'c'
            target :q6
          end
        end
      end

      question :q2 do
        deps :flag1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: 'a', a2: true, a3: true, a4: 30)
    assert_equal %w[q2], action.skip
    assert_equal %w[q3 q4 q5], action.recover

    action = applier.apply(:q1, a1: 'a', a2: true, a3: false, a4: 30)
    assert_equal %w[q2 q3], action.skip
    assert_equal %w[q4 q5], action.recover

    action = applier.apply(:q1, a1: 'a', a2: false, a3: true, a4: 30)
    assert_equal %w[q2 q3 q4], action.skip
    assert_equal %w[q5], action.recover

    action = applier.apply(:q1, a1: 'b', a2: true, a3: true, a4: 60)
    assert_equal %w[q2], action.skip
    assert_equal %w[q3 q4 q5], action.recover

    action = applier.apply(:q1, a1: 'b', a2: true, a3: true, a4: 40)
    assert_equal %w[q2 q3 q4 q5], action.skip
    assert_empty action.recover

    action = applier.apply(:q1, a1: 'c', a2: true, a3: true, a4: 60)
    assert_equal %w[q2 q3 q4 q5], action.skip
    assert_empty action.recover
  end

  def test_empty_rule
    rule = QFlow.define

    applier = QFlow.use(rule)

    action = applier.apply('any_question')
    assert_empty action.skip
    assert_empty action.recover
  end

  def test_nonexistent_question
    rule = QFlow.define(%i[q1 q2]) do
      question :q1 do
        args :a1
        targets :q2
        transitions do
          target :q2
        end
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:nonexistent)
    assert_empty action.skip
    assert_empty action.recover
  end

  def test_question_without_transitions
    rule = QFlow.define(%i[q1 q2]) do
      question :q1 do
        effects :flag1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1)
    assert_empty action.skip
    assert_empty action.recover
  end

  def test_transition_to_nonexistent_question
    rule = QFlow.define(%i[q1 q2 q3]) do
      question :q1 do
        args :a1
        targets :q3
        transitions do
          target :q3
        end
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: 'ok')
    assert_equal %w[q2], action.skip
    assert_empty action.recover
  end

  def test_missing_required_dependencies
    rule = QFlow.define(%i[q1 q2]) do
      question :q1 do
        args :a1, :required_arg
        targets :q2
        transitions do
          target :q2
        end
      end
    end

    applier = QFlow.use(rule)

    error = assert_raises ArgumentError do
      applier.apply(:q1, a1: 'ok')
    end
    assert_match(/Error: question 'q1' missing parameters: required_arg/, error.message)
  end

  def test_missing_multiple_dependencies
    rule = QFlow.define(%i[q1 q2]) do
      question :q1 do
        args :a1, :a2, :required_arg1, :required_arg2
        targets :q2
        transitions do
          target :q2
        end
      end
    end

    applier = QFlow.use(rule)

    error = assert_raises ArgumentError do
      applier.apply(:q1, a1: 'ok', a2: 'value')
    end
    assert_match(/Error: question 'q1' missing parameters: required_arg1, required_arg2/, error.message)
  end

  def test_smart_parameter_handling_no_answer_parameter
    rule = QFlow.define(%i[q1 q2 q3]) do
      question :q1 do
        effects :flag1
        args :a1
        targets :q2, :q3
        transitions do
          target a1 ? :q3 : :q2
        end
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: true)
    assert_equal %w[q2], action.skip
    assert_empty action.recover
  end

  def test_smart_parameter_handling_with_deps_but_no_answer_parameter
    rule = QFlow.define(%i[q1 q2 q3 q4]) do
      question :q1 do
        effects :flag1
        args :a1
        targets :q3, :q4
        transitions do
          target a1 ? :q3 : :q4
        end
      end

      question :q2 do
        deps :flag1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: true)
    assert_equal %w[q2], action.skip
    assert_equal %w[q3], action.recover

    action = applier.apply(:q1, a1: false)
    assert_equal %w[q2 q3], action.skip
    assert_empty action.recover
  end

  def test_empty_current_question
    rule = QFlow.define(%i[q1 q2]) do
      question :q1 do
        args :a1
        targets :q2
        transitions do
          target :q2
        end
      end
    end

    applier = QFlow.use(rule)

    error = assert_raises ArgumentError do
      applier.apply('')
    end
    assert_match(/Error: question code cannot be empty/, error.message)

    error = assert_raises ArgumentError do
      applier.apply(nil)
    end
    assert_match(/Error: question code cannot be empty/, error.message)
  end

  def test_invalid_question_flow_backward_jump
    rule = QFlow.define(%i[q1 q2 q3]) do
      question :q2 do
        args :a1
        targets :q1, :q3
        transitions do
          case a1
          in 'back'
            target :q1
          in 'forward'
            target :q3
          end
        end
      end
    end

    applier = QFlow.use(rule)

    error = assert_raises QFlow::FlowError do
      applier.apply(:q2, a1: 'back')
    end
    assert_match(/Error: invalid question flow: current=q2, next=q1/, error.message)

    action = applier.apply(:q2, a1: 'forward')
    assert_empty action.skip
    assert_empty action.recover
  end

  def test_invalid_question_flow_same_question
    error = assert_raises QFlow::DefinitionError do
      QFlow.define(%i[q1 q2]) do
        question :q1 do
          args :a1
          targets :q1
          transitions do
            target :q1
          end
        end
      end
    end
    assert_match(/Error: question 'q1' cannot target itself in its own targets list/, error.message)
  end

  def test_invalid_question_flow_nonexistent_target
    error = assert_raises QFlow::DefinitionError do
      QFlow.define(%i[q1 q2]) do
        question :q1 do
          args :a1
          targets :nonexistent
          transitions do
            target :nonexistent
          end
        end
      end
    end
    assert_match(/Error: targets.*are not defined in question codes/, error.message)
  end

  def test_transitions_block_misuse_in_wrong_context
    rule = QFlow.define(%i[q1 q2]) do
      question :q1 do
        args :a1
        targets :q2
        transitions do
          args 'should_not_work'
          target :q2
        end
      end
    end

    applier = QFlow.use(rule)

    error = assert_raises QFlow::UsageError do
      applier.apply(:q1, a1: true)
    end
    assert_match(/Error: 'args' should be called in the question definition block/, error.message)
  end

  def test_empty_target
    rule = QFlow.define(%i[q1 q2]) do
      question :q1 do
        args :a1
        targets :q2
        transitions do
          target ''
        end
      end
    end

    applier = QFlow.use(rule)

    error = assert_raises ArgumentError do
      applier.apply(:q1, a1: 'ok')
    end
    assert_match(/Error: question 'q1' has defined a target but it is empty/, error.message)
  end

  def test_skip_and_recover_should_not_overlap
    rule = QFlow.define(%i[q1 q2 q3 q4 q5]) do
      question :q1 do
        args :a1
        effects :flag1
        targets :q5
        transitions do
          target :q5
        end
      end

      question :q2 do
        deps :flag1
      end

      question :q3 do
        deps :flag1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: 'skip_to_end')
    skip_questions = action.skip
    recover_questions = action.recover

    overlap = skip_questions & recover_questions
    assert_empty overlap, "Skip and recover should not overlap: #{overlap}"
  end

  def test_multiple_questions_with_complex_flow
    rule = QFlow.define(%i[q1 q2 q3 q4 q5 q6]) do
      question :q1 do
        args :a1
        effects :flag1
        targets :q5
        transitions do
          target :q5
        end
      end

      question :q2 do
        deps :flag1
      end

      question :q3 do
        deps :flag1
      end

      question :q4 do
        args :a1
        effects :flag2
        targets :q5, :q6

        transitions do
          case a1
          in 'continue'
            target :q5
          in 'skip'
            target :q6
          end
        end
      end

      question :q5 do
        deps :flag2
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: 'start')
    assert_equal %w[q2 q3 q4], action.skip
    assert_empty action.recover

    action = applier.apply(:q4, a1: 'continue')
    assert_empty action.skip
    assert_equal %w[q5], action.recover

    action = applier.apply(:q4, a1: 'skip')
    assert_equal %w[q5], action.skip
    assert_empty action.recover
  end

  def test_question_defined_in_initial_list_but_not_in_block
    rule = QFlow.define(%i[q1 q2 q3 q4]) do
      question :q1 do
        args :a1
        targets :q4
        transitions do
          target :q4
        end
      end
    end

    applier = QFlow.use(rule)
    action = applier.apply(:q1, a1: 'jump')
    assert_equal %w[q2 q3], action.skip
    assert_empty action.recover

    action = applier.apply(:q2)
    assert_empty action.skip
    assert_empty action.recover

    action = applier.apply(:q3)
    assert_empty action.skip
    assert_empty action.recover
  end

  def test_multiple_effects_and_complex_recovery
    rule = QFlow.define(%i[q1 q2 q3 q4 q5]) do
      question :q1 do
        args :a1
        effects :flag1, :flag2
        targets :q5
        transitions do
          target :q5
        end
      end

      question :q2 do
        deps :flag1
      end

      question :q3 do
        deps :flag2
      end

      question :q4 do
        deps :flag1, :flag2
      end
    end

    applier = QFlow.use(rule)
    action = applier.apply(:q1, a1: 'proceed')
    assert_equal %w[q2 q3 q4], action.skip
    assert_empty action.recover
  end

  def test_multiple_calls_in_real_scenario
    rule = QFlow.define(%i[q1 q2 q3 q4 q5]) do
      question :q1 do
        args :a1
        effects :flag1
        targets :q3

        args :a2, :a3
        effects :flag2
        targets :q4, :q5

        transitions do
          case a1
          in 'path1'
            target a2 ? :q3 : :q4
          in 'path2'
            target a3 ? :q4 : :q5
          end
        end
      end

      question :q2 do
        deps :flag1
        deps :flag2
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: 'path1', a2: true, a3: false)
    assert_equal %w[q2], action.skip
    assert_equal %w[q3 q4], action.recover

    action = applier.apply(:q1, a1: 'path2', a2: false, a3: true, extra_param: 'ignored')
    assert_equal %w[q2 q3], action.skip
    assert_equal %w[q4], action.recover
  end

  def test_all_string_parameters_applier
    rule = QFlow.define(%i[q1 q2 q3 q4]) do
      question 'q1' do
        args 'a1'
        effects 'flag1'
        targets 'q3', 'q4'

        transitions do
          case a1
          in 'yes'
            target 'q3'
          in 'no'
            target 'q4'
          end
        end
      end

      question 'q2' do
        deps 'flag1'
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply('q1', a1: 'yes')
    assert_equal %w[q2], action.skip
    assert_equal %w[q3], action.recover

    action = applier.apply('q1', a1: 'no')
    assert_equal %w[q2 q3], action.skip
    assert_empty action.recover
  end

  def test_mixed_string_and_symbol_parameters_applier
    rule = QFlow.define(['q1', :q2, 'q3', :q4]) do
      question 'q1' do
        args 'a1', :a2
        effects :flag1, 'flag2'
        targets 'q3', :q4

        transitions do
          case a1
          in 'option1'
            target a2 ? 'q3' : :q4
          in 'option2'
            target :q4
          end
        end
      end

      question :q2 do
        deps 'flag1', :flag2
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply('q1', a1: 'option1', a2: true)
    assert_equal %w[q2], action.skip
    assert_equal %w[q3], action.recover

    action = applier.apply('q1', a1: 'option1', a2: false)
    assert_equal %w[q2 q3], action.skip
    assert_empty action.recover

    action = applier.apply(:q1, a1: 'option2', a2: true)
    assert_equal %w[q2 q3], action.skip
    assert_empty action.recover
  end
end
