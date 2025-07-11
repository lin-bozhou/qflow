# QFlow

QFlow is a Ruby DSL for defining questionnaire flow logic with conditional transitions, dependencies, and automatic skip/recovery calculations.

## Features

- **Zero Dependencies**: No external runtime dependencies
- **Declarative**: Define flow logic using a clean, readable DSL
- **Immutable**: Only performs calculations without modifying external state or variables
- **Robust Validation**: Comprehensive error detection and validation with clear error messages

## Installation

Add to Gemfile:

```ruby
gem 'qflow'
```

And then execute:

```shell
bundle install
```

## Usage

### Basic Example

```ruby
require 'qflow'

# Define a questionnaire flow
rule = QFlow.define(%w[q1 q2 q3 q4]) do
  question :q1 do
    args :answer
    effects :flag1
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

  question :q2 do
    deps :flag1 # Depends on effect from q1
  end
end

# Create an applier to calculate flow actions
applier = QFlow.use(rule)

# Calculate which questions to skip and recover
action = applier.apply(:q1, answer: 'yes')
puts action[:skip] # => ["q2"] (questions to skip)
puts action[:recover] # => ["q3", "q4"] (questions to recover)
```

### DSL Components

#### Question Definition
- **args**: Parameters required for the question's transitions
- **effects**: Variables/flags this question produces
- **deps**: Dependencies on effects from other questions  
- **targets**: Possible next questions this can transition to
- **transitions**: Logic block that determines the next question
  - **target**: Specifies the next question based on conditions

#### Flow Calculation
- **skip**: Questions between current and target that should be skipped
- **recover**: Questions that should be shown based on dependencies and targets
