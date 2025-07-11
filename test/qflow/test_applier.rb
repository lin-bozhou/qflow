# frozen_string_literal: true

require_relative '../test_helper'

class TestApplier < Minitest::Test
  def test_basic_question_transitions
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q1 do
        args :answer
        targets :q3, :q4
        transitions do
          case answer
          when 'yes'
            target :q3
          when 'no'
            target :q4
          end
        end
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, answer: 'yes')
    assert_equal ['q2'], action[:skip]
    assert_equal %w[q3 q4], action[:recover]

    action = applier.apply(:q1, answer: 'no')
    assert_equal %w[q2 q3], action[:skip]
    assert_equal ['q4'], action[:recover]
  end

  def test_question_with_dependencies
    rule = QFlow.define(%w[q1 q2 q3 q4 q5]) do
      question :q1 do
        args :answer, :condition
        effects :e1
        targets :q3, :q4, :q5

        transitions do
          case answer
          when 'option1'
            target condition ? :q3 : :q4
          when 'option2'
            target :q5
          end
        end
      end

      question :q2 do
        deps :e1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, answer: 'option1', condition: true)
    assert_equal ['q2'], action[:skip]
    assert_equal %w[q3 q4 q5], action[:recover]

    action = applier.apply(:q1, answer: 'option1', condition: false)
    assert_equal %w[q2 q3], action[:skip]
    assert_equal %w[q4 q5], action[:recover]

    action = applier.apply(:q1, answer: 'option2', condition: true)
    assert_equal %w[q2 q3 q4], action[:skip]
    assert_equal %w[q5], action[:recover]
  end

  def test_question_with_effects_and_recovery
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q1 do
        args :answer
        effects :important_flag
        targets :q3, :q4

        transitions do
          case answer
          when true
            target :q3
          when false
            target :q4
          end
        end
      end

      question :q2 do
        deps :important_flag
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, answer: true)
    assert_equal ['q2'], action[:skip]
    assert_equal %w[q3 q4], action[:recover]

    action = applier.apply(:q1, answer: false)
    assert_equal %w[q2 q3], action[:skip]
    assert_equal %w[q4], action[:recover]
  end

  def test_transitions_without_predefined_answer_values
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q1 do
        effects :e1
        args :condition
        targets :q3, :q4
        transitions do
          target condition ? :q3 : :q4
        end
      end

      question :q2 do
        deps :e1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, condition: true)
    assert_equal ['q2'], action[:skip]
    assert_equal %w[q3 q4], action[:recover]
  end

  def test_transitions_with_complex_dependencies
    rule = QFlow.define(%w[q1 q2 q3 q4 q5 q6]) do
      question :q1 do
        args :answer, :flag1, :flag2, :value
        effects :result_type
        targets :q3, :q4, :q5, :q6

        transitions do
          case answer
          when 'a'
            if flag1 && flag2
              target :q3
            elsif flag1
              target :q4
            else
              target :q5
            end
          when 'b'
            target value > 50 ? :q3 : :q6
          when 'c'
            target :q6
          end
        end
      end

      question :q2 do
        deps :result_type
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, answer: 'a', flag1: true, flag2: true, value: 30)
    assert_equal ['q2'], action[:skip]
    assert_equal %w[q3 q4 q5 q6], action[:recover]

    action = applier.apply(:q1, answer: 'a', flag1: true, flag2: false, value: 30)
    assert_equal %w[q2 q3], action[:skip]
    assert_equal %w[q4 q5 q6], action[:recover]

    action = applier.apply(:q1, answer: 'a', flag1: false, flag2: true, value: 30)
    assert_equal %w[q2 q3 q4], action[:skip]
    assert_equal %w[q5 q6], action[:recover]

    action = applier.apply(:q1, answer: 'b', flag1: true, flag2: true, value: 60)
    assert_equal ['q2'], action[:skip]
    assert_equal %w[q3 q4 q5 q6], action[:recover]

    action = applier.apply(:q1, answer: 'b', flag1: true, flag2: true, value: 40)
    assert_equal %w[q2 q3 q4 q5], action[:skip]
    assert_equal %w[q6], action[:recover]

    action = applier.apply(:q1, answer: 'c', flag1: true, flag2: true, value: 60)
    assert_equal %w[q2 q3 q4 q5], action[:skip]
    assert_equal %w[q6], action[:recover]
  end

  def test_empty_rule
    rule = QFlow.define

    applier = QFlow.use(rule)

    action = applier.apply('any_question')
    assert_equal [], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_nonexistent_question
    rule = QFlow.define(%w[q1 q2]) do
      question :q1 do
        args :answer
        targets :q2
        transitions do
          target :q2
        end
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:nonexistent)
    assert_equal [], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_question_without_transitions
    rule = QFlow.define(%w[q1 q2]) do
      question :q1 do
        effects :e1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1)
    assert_equal [], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_transition_to_nonexistent_question
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        args :answer
        targets :q3
        transitions do
          target :q3
        end
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, answer: 'ok')
    assert_equal ['q2'], action[:skip]
    assert_equal ['q3'], action[:recover]
  end

  def test_missing_required_dependencies
    rule = QFlow.define(%w[q1 q2]) do
      question :q1 do
        args :answer, :required_param
        targets :q2
        transitions do
          target :q2
        end
      end
    end

    applier = QFlow.use(rule)

    error = assert_raises ArgumentError do
      applier.apply(:q1, answer: 'ok')
    end
    assert_match(/Error: question 'q1' missing parameters: required_param/, error.message)
  end

  def test_missing_multiple_dependencies
    rule = QFlow.define(%w[q1 q2]) do
      question :q1 do
        args :answer, :param1, :param2, :param3
        targets :q2
        transitions do
          target :q2
        end
      end
    end

    applier = QFlow.use(rule)

    error = assert_raises ArgumentError do
      applier.apply(:q1, answer: 'ok', param2: 'value')
    end
    assert_match(/Error: question 'q1' missing parameters: param1, param3/, error.message)
  end

  def test_smart_parameter_handling_no_answer_parameter
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q1 do
        effects :e1
        args :condition
        targets :q2, :q3
        transitions do
          target condition ? :q3 : :q2
        end
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, condition: true)
    assert_equal ['q2'], action[:skip]
    assert_equal ['q3'], action[:recover]
  end

  def test_smart_parameter_handling_with_deps_but_no_answer_parameter
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q1 do
        effects :e1
        args :condition
        targets :q3, :q4
        transitions do
          target condition ? :q3 : :q4
        end
      end

      question :q2 do
        deps :e1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, condition: true)
    assert_equal ['q2'], action[:skip]
    assert_equal %w[q3 q4], action[:recover]

    action = applier.apply(:q1, condition: false)
    assert_equal %w[q2 q3], action[:skip]
    assert_equal %w[q4], action[:recover]
  end

  def test_empty_current_question
    rule = QFlow.define(%w[q1 q2]) do
      question :q1 do
        args :answer
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
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q2 do
        args :answer
        targets :q1, :q3
        transitions do
          case answer
          when 'back'
            target :q1
          when 'forward'
            target :q3
          end
        end
      end
    end

    applier = QFlow.use(rule)

    error = assert_raises QFlow::FlowError do
      applier.apply(:q2, answer: 'back')
    end
    assert_match(/Error: invalid question flow: current=q2, next=q1/, error.message)

    action = applier.apply(:q2, answer: 'forward')
    assert_equal [], action[:skip]
    assert_equal ['q3'], action[:recover]
  end

  def test_invalid_question_flow_same_question
    error = assert_raises QFlow::DefinitionError do
      QFlow.define(%w[q1 q2]) do
        question :q1 do
          args :answer
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
      QFlow.define(%w[q1 q2]) do
        question :q1 do
          args :answer
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
    rule = QFlow.define(%w[q1 q2]) do
      question :q1 do
        args :answer
        targets :q2
        transitions do
          args 'should_not_work'
          target :q2
        end
      end
    end

    applier = QFlow.use(rule)

    error = assert_raises QFlow::UsageError do
      applier.apply(:q1, answer: true)
    end
    assert_match(/Error: 'args' should be called in the question definition block/, error.message)
  end

  def test_empty_target
    rule = QFlow.define(%w[q1 q2]) do
      question :q1 do
        args :answer
        targets :q2
        transitions do
          target ''
        end
      end
    end

    applier = QFlow.use(rule)

    error = assert_raises ArgumentError do
      applier.apply(:q1, answer: 'ok')
    end
    assert_match(/Error: question 'q1' has defined a target but it is empty/, error.message)
  end

  def test_skip_and_recover_should_not_overlap
    rule = QFlow.define(%w[q1 q2 q3 q4 q5]) do
      question :q1 do
        args :answer
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

    action = applier.apply(:q1, answer: 'skip_to_end')
    skip_questions = action[:skip]
    recover_questions = action[:recover]

    # Check that skip and recover don't overlap
    overlap = skip_questions & recover_questions
    assert_equal [], overlap, "Skip and recover should not overlap: #{overlap}"
  end

  def test_multiple_questions_with_complex_flow
    rule = QFlow.define(%w[q1 q2 q3 q4 q5 q6]) do
      question :q1 do
        args :answer
        effects :started
        targets :q5
        transitions do
          target :q5
        end
      end

      question :q2 do
        deps :started
      end

      question :q3 do
        deps :started
      end

      question :q4 do
        args :answer, :started
        effects :decision_made
        targets :q5, :q6

        transitions do
          case answer
          when 'continue'
            target :q5
          when 'skip'
            target :q6
          end
        end
      end

      question :q5 do
        deps :decision_made
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, answer: 'start')
    assert_equal %w[q2 q3 q4], action[:skip]
    assert_equal %w[q5], action[:recover]

    action = applier.apply(:q4, answer: 'continue', started: true)
    assert_equal [], action[:skip]
    assert_equal %w[q5 q6], action[:recover]

    action = applier.apply(:q4, answer: 'skip', started: true)
    assert_equal ['q5'], action[:skip]
    assert_equal %w[q6], action[:recover]
  end

  def test_question_defined_in_initial_list_but_not_in_block
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q1 do
        args :answer
        targets :q4
        transitions do
          target :q4
        end
      end
    end

    applier = QFlow.use(rule)
    action = applier.apply(:q1, answer: 'jump')
    assert_equal %w[q2 q3], action[:skip]
    assert_equal ['q4'], action[:recover]

    action = applier.apply(:q2)
    assert_equal [], action[:skip]
    assert_equal [], action[:recover]

    action = applier.apply(:q3)
    assert_equal [], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_multiple_effects_and_complex_recovery
    rule = QFlow.define(%w[q1 q2 q3 q4 q5]) do
      question :q1 do
        args :answer
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
    action = applier.apply(:q1, answer: 'proceed')
    assert_equal %w[q2 q3 q4], action[:skip]
    assert_equal %w[q5], action[:recover]
  end

  def test_complex_flow_with_multiple_conditions
    questions = %i[
      start
      basic_infos
      householder
      former_jobs
      other_income_type
      all_income
      working_student
      handicap
      widow
      spouse
      dependents
      adj_in_this_company
      resign_in_year
      disaster_sufferer
      tax_schedule
      multi_companies
      salary_more
      life_insurances
      earthquake_insurances
      social_insurances
      premium
      housing_loan
      basic_infos_next
      householder_next
      all_income_next
      working_student_next
      handicap_next
      widow_next
      spouse_next
      dependents_next
      tax_schedule_next
      multi_companies_next
      salary_more_next
      attachments
    ]
    defined_questions = %i[
      other_income_type
      all_income
      adj_in_this_company
      resign_in_year
      disaster_sufferer
      tax_schedule
      multi_companies
      salary_more
      tax_schedule_next
      multi_companies_next
    ]
    rule = QFlow.define(questions) do
      question :other_income_type do
        effects :income_type
      end

      question :all_income do
        deps :income_type
      end

      question :adj_in_this_company do
        args :answer
        effects :adj, :resign
        targets :resign_in_year, :tax_schedule
        transitions do
          case answer
          when true
            target :resign_in_year
          when false
            target :tax_schedule
          end
        end
      end

      question :resign_in_year do
        args :answer
        effects :resign, :adj
        targets :disaster_sufferer, :tax_schedule
        transitions do
          case answer
          when true
            target :tax_schedule
          when false
            target :disaster_sufferer
          end
        end
      end

      question :disaster_sufferer do
        effects :adj
      end

      question :tax_schedule do
        args :answer, :resign_before_year_end, :not_need_adj
        deps :resign, :adj
        targets :multi_companies, :attachments, :basic_infos_next, :life_insurances
        transitions do
          case answer
          when 'first'
            if !not_need_adj
              target :life_insurances
            elsif not_need_adj && resign_before_year_end
              target :attachments
            elsif not_need_adj && !resign_before_year_end
              target :basic_infos_next
            end
          when 'second'
            if resign_before_year_end
              target :attachments
            else
              target :basic_infos_next
            end
          when nil
            target :multi_companies
          end
        end
      end

      question :multi_companies do
        args :answer, :resign_before_year_end, :not_need_adj
        deps :resign, :adj
        targets :salary_more, :attachments, :basic_infos_next, :life_insurances
        transitions do
          case answer
          when true
            target :salary_more
          when false
            if !not_need_adj
              target :life_insurances
            elsif not_need_adj && resign_before_year_end
              target :attachments
            elsif not_need_adj && !resign_before_year_end
              target :basic_infos_next
            end
          end
        end
      end

      question :salary_more do
        args :answer, :resign_before_year_end, :not_need_adj
        deps :resign, :adj
        targets :life_insurances, :attachments, :basic_infos_next
        transitions do
          case answer
          when true
            if !not_need_adj
              target :life_insurances
            elsif not_need_adj && resign_before_year_end
              target :attachments
            elsif not_need_adj && !resign_before_year_end
              target :basic_infos_next
            end
          when false
            if resign_before_year_end
              target :attachments
            else
              target :basic_infos_next
            end
          end
        end
      end

      question :tax_schedule_next do
        args :answer
        targets :multi_companies_next, :attachments
        transitions do
          case answer
          when 'first', 'second'
            target :attachments
          when nil
            target :multi_companies_next
          end
        end
      end

      question :multi_companies_next do
        args :answer
        targets :salary_more_next, :attachments
        transitions do
          case answer
          when true
            target :salary_more_next
          when false
            target :attachments
          end
        end
      end
    end

    defined_questions.each do |q|
      refute_nil rule.configs[q], "Configuration for question #{q} is missing"
    end
    assert_equal questions, rule.codes

    applier = QFlow.use(rule)

    # other_income_type
    action = applier.apply(:other_income_type)
    assert_equal %w[], action[:skip]
    assert_equal %w[all_income], action[:recover]

    # all_income
    # adj_in_this_company
    # resign_in_year
    # disaster_sufferer
    # tax_schedule
    # multi_companies
    # salary_more
    # tax_schedule_next
    # multi_companies_next
  end
end
