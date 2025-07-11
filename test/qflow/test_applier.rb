# frozen_string_literal: true

require_relative '../test_helper'

class TestApplier < Minitest::Test
  def test_basic_question_transitions
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q1 do
        args :a1
        targets :q3, :q4
        transitions do
          case a1
          when 'yes'
            target :q3
          when 'no'
            target :q4
          end
        end
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1, a1: 'yes')
    assert_equal %w[q2], action[:skip]
    assert_equal %w[q3], action[:recover]

    action = applier.apply(:q1, a1: 'no')
    assert_equal %w[q2 q3], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_question_with_dependencies
    rule = QFlow.define(%w[q1 q2 q3 q4 q5]) do
      question :q1 do
        args :a1, :a2
        effects :flag1
        targets :q3, :q4, :q5

        transitions do
          case a1
          when 'option1'
            target a2 ? :q3 : :q4
          when 'option2'
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
    assert_equal %w[q2], action[:skip]
    assert_equal %w[q3 q4], action[:recover]

    action = applier.apply(:q1, a1: 'option1', a2: false)
    assert_equal %w[q2 q3], action[:skip]
    assert_equal %w[q4], action[:recover]

    action = applier.apply(:q1, a1: 'option2', a2: true)
    assert_equal %w[q2 q3 q4], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_question_with_effects_and_recovery
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
      question :q1 do
        args :a1
        effects :flag1
        targets :q3, :q4

        transitions do
          case a1
          when true
            target :q3
          when false
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
    assert_equal %w[q2], action[:skip]
    assert_equal %w[q3], action[:recover]

    action = applier.apply(:q1, a1: false)
    assert_equal %w[q2 q3], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_transitions_without_predefined_answer_values
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
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
    assert_equal %w[q2], action[:skip]
    assert_equal %w[q3], action[:recover]
  end

  def test_transitions_with_complex_dependencies
    rule = QFlow.define(%w[q1 q2 q3 q4 q5 q6]) do
      question :q1 do
        args :a1, :a2, :a3, :a4
        effects :flag1
        targets :q3, :q4, :q5, :q6

        transitions do
          case a1
          when 'a'
            if a2 && a3
              target :q3
            elsif a2
              target :q4
            else
              target :q5
            end
          when 'b'
            target a4 > 50 ? :q3 : :q6
          when 'c'
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
    assert_equal %w[q2], action[:skip]
    assert_equal %w[q3 q4 q5], action[:recover]

    action = applier.apply(:q1, a1: 'a', a2: true, a3: false, a4: 30)
    assert_equal %w[q2 q3], action[:skip]
    assert_equal %w[q4 q5], action[:recover]

    action = applier.apply(:q1, a1: 'a', a2: false, a3: true, a4: 30)
    assert_equal %w[q2 q3 q4], action[:skip]
    assert_equal %w[q5], action[:recover]

    action = applier.apply(:q1, a1: 'b', a2: true, a3: true, a4: 60)
    assert_equal %w[q2], action[:skip]
    assert_equal %w[q3 q4 q5], action[:recover]

    action = applier.apply(:q1, a1: 'b', a2: true, a3: true, a4: 40)
    assert_equal %w[q2 q3 q4 q5], action[:skip]
    assert_equal [], action[:recover]

    action = applier.apply(:q1, a1: 'c', a2: true, a3: true, a4: 60)
    assert_equal %w[q2 q3 q4 q5], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_empty_rule
    rule = QFlow.define

    applier = QFlow.use(rule)

    action = applier.apply('any_question')
    assert_empty action[:skip]
    assert_empty action[:recover]
  end

  def test_nonexistent_question
    rule = QFlow.define(%w[q1 q2]) do
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
    assert_empty action[:skip]
    assert_empty action[:recover]
  end

  def test_question_without_transitions
    rule = QFlow.define(%w[q1 q2]) do
      question :q1 do
        effects :flag1
      end
    end

    applier = QFlow.use(rule)

    action = applier.apply(:q1)
    assert_empty action[:skip]
    assert_empty action[:recover]
  end

  def test_transition_to_nonexistent_question
    rule = QFlow.define(%w[q1 q2 q3]) do
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
    assert_equal %w[q2], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_missing_required_dependencies
    rule = QFlow.define(%w[q1 q2]) do
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
    rule = QFlow.define(%w[q1 q2]) do
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
    rule = QFlow.define(%w[q1 q2 q3]) do
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
    assert_equal %w[q2], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_smart_parameter_handling_with_deps_but_no_answer_parameter
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
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
    assert_equal %w[q2], action[:skip]
    assert_equal %w[q3], action[:recover]

    action = applier.apply(:q1, a1: false)
    assert_equal %w[q2 q3], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_empty_current_question
    rule = QFlow.define(%w[q1 q2]) do
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
    rule = QFlow.define(%w[q1 q2 q3]) do
      question :q2 do
        args :a1
        targets :q1, :q3
        transitions do
          case a1
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
      applier.apply(:q2, a1: 'back')
    end
    assert_match(/Error: invalid question flow: current=q2, next=q1/, error.message)

    action = applier.apply(:q2, a1: 'forward')
    assert_empty action[:skip]
    assert_equal [], action[:recover]
  end

  def test_invalid_question_flow_same_question
    error = assert_raises QFlow::DefinitionError do
      QFlow.define(%w[q1 q2]) do
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
      QFlow.define(%w[q1 q2]) do
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
    rule = QFlow.define(%w[q1 q2]) do
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
    rule = QFlow.define(%w[q1 q2]) do
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
    rule = QFlow.define(%w[q1 q2 q3 q4 q5]) do
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
    skip_questions = action[:skip]
    recover_questions = action[:recover]

    overlap = skip_questions & recover_questions
    assert_empty overlap, "Skip and recover should not overlap: #{overlap}"
  end

  def test_multiple_questions_with_complex_flow
    rule = QFlow.define(%w[q1 q2 q3 q4 q5 q6]) do
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
          when 'continue'
            target :q5
          when 'skip'
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
    assert_equal %w[q2 q3 q4], action[:skip]
    assert_equal [], action[:recover]

    action = applier.apply(:q4, a1: 'continue')
    assert_empty action[:skip]
    assert_equal %w[q5], action[:recover]

    action = applier.apply(:q4, a1: 'skip')
    assert_equal %w[q5], action[:skip]
    assert_equal [], action[:recover]
  end

  def test_question_defined_in_initial_list_but_not_in_block
    rule = QFlow.define(%w[q1 q2 q3 q4]) do
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
    assert_equal %w[q2 q3], action[:skip]
    assert_equal [], action[:recover]

    action = applier.apply(:q2)
    assert_empty action[:skip]
    assert_empty action[:recover]

    action = applier.apply(:q3)
    assert_empty action[:skip]
    assert_empty action[:recover]
  end

  def test_multiple_effects_and_complex_recovery
    rule = QFlow.define(%w[q1 q2 q3 q4 q5]) do
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
    assert_equal %w[q2 q3 q4], action[:skip]
    assert_equal [], action[:recover]
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
    def questions.between(start_code, end_code)
      start_index = index(start_code.to_sym)
      end_index = index(end_code.to_sym)

      if start_index.nil? || end_index.nil? || start_index > end_index
        raise ArgumentError,
              "Invalid question codes: start_code=#{start_code}, end_code=#{end_code}"
      end

      self[start_index..end_index].map(&:to_s)
    end
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
        effects :need_adj
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
        effects :need_adj, :resign
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
        effects :need_adj
      end

      question :tax_schedule do
        args :answer, :not_need_adj, :resign_before_year_end
        deps :need_adj, :resign
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
        args :answer, :not_need_adj, :resign_before_year_end
        deps :need_adj, :resign
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
        args :answer, :not_need_adj, :resign_before_year_end
        deps :need_adj, :resign
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

    questions.each do |q|
      if defined_questions.include?(q)
        refute_nil rule.configs[q], "Configuration for question #{q} is missing"
      else
        assert_nil rule.configs[q], "Configuration for question #{q} should not exist"
      end
    end
    assert_equal questions, rule.codes

    applier = QFlow.use(rule)

    # not directly defined questions
    (questions - defined_questions).each do |q|
      action = applier.apply(q)
      assert_empty action[:skip]
      assert_empty action[:recover]
    end

    # other_income_type
    action = applier.apply(:other_income_type)
    assert_empty action[:skip]
    assert_equal %w[all_income], action[:recover]

    # all_income
    action = applier.apply(:all_income)
    assert_empty action[:skip]
    assert_empty action[:recover]

    # adj_in_this_company
    action = applier.apply(:adj_in_this_company, answer: true)
    assert_empty action[:skip]
    assert_equal questions.between(:resign_in_year, :salary_more), action[:recover]

    action = applier.apply(:adj_in_this_company, answer: false)
    assert_equal %w[resign_in_year disaster_sufferer], action[:skip]
    assert_equal questions.between(:tax_schedule, :salary_more), action[:recover]

    # resign_in_year
    action = applier.apply(:resign_in_year, answer: true)
    assert_equal %w[disaster_sufferer], action[:skip]
    assert_equal questions.between(:tax_schedule, :salary_more), action[:recover]

    action = applier.apply(:resign_in_year, answer: false)
    assert_empty action[:skip]
    assert_equal questions.between(:disaster_sufferer, :salary_more), action[:recover]

    # disaster_sufferer
    action = applier.apply(:disaster_sufferer)
    assert_empty action[:skip]
    assert_equal questions.between(:tax_schedule, :salary_more), action[:recover]

    # tax_schedule
    action = applier.apply(:tax_schedule, answer: 'first', not_need_adj: true, resign_before_year_end: true)
    assert_equal questions.between(:multi_companies, :salary_more_next), action[:skip]
    assert_empty action[:recover]
    action = applier.apply(:tax_schedule, answer: 'first', not_need_adj: true, resign_before_year_end: false)
    assert_equal questions.between(:multi_companies, :housing_loan), action[:skip]
    assert_equal questions.between(:basic_infos_next, :salary_more_next), action[:recover]
    action = applier.apply(:tax_schedule, answer: 'first', not_need_adj: false, resign_before_year_end: true)
    assert_equal questions.between(:multi_companies, :salary_more), action[:skip]
    assert_equal questions.between(:life_insurances, :salary_more_next), action[:recover]
    action = applier.apply(:tax_schedule, answer: 'first', not_need_adj: false, resign_before_year_end: false)
    assert_equal questions.between(:multi_companies, :salary_more), action[:skip]
    assert_equal questions.between(:life_insurances, :salary_more_next), action[:recover]

    action = applier.apply(:tax_schedule, answer: 'second', not_need_adj: true, resign_before_year_end: true)
    assert_equal questions.between(:multi_companies, :salary_more_next), action[:skip]
    assert_empty action[:recover]
    action = applier.apply(:tax_schedule, answer: 'second', not_need_adj: true, resign_before_year_end: false)
    assert_equal questions.between(:multi_companies, :housing_loan), action[:skip]
    assert_equal questions.between(:basic_infos_next, :salary_more_next), action[:recover]
    action = applier.apply(:tax_schedule, answer: 'second', not_need_adj: false, resign_before_year_end: true)
    assert_equal questions.between(:multi_companies, :salary_more_next), action[:skip]
    assert_empty action[:recover]
    action = applier.apply(:tax_schedule, answer: 'second', not_need_adj: false, resign_before_year_end: false)
    assert_equal questions.between(:multi_companies, :housing_loan), action[:skip]
    assert_equal questions.between(:basic_infos_next, :salary_more_next), action[:recover]

    [true, false].product([true, false]).each do |not_need_adj, resign_before_year_end|
      action = applier.apply(:tax_schedule, answer: nil, not_need_adj:, resign_before_year_end:)
      assert_empty action[:skip]
      assert_equal questions.between(:multi_companies, :salary_more_next), action[:recover]
    end

    # multi_companies

    # salary_more

    # tax_schedule_next

    # multi_companies_next
  end
end
