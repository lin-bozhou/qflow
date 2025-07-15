# QFlow

QFlow is a Ruby DSL for defining questionnaire flow logic with conditional transitions, dependencies, and automatic skip/recovery calculations.

## Features

- **Zero Dependencies**: No external runtime dependencies
- **Declarative**: Define flow logic using a clean, readable DSL
- **Side-Effect Free**: Only performs calculations without modifying external state or variables
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
    effects :flag1 # When answered, affects questions that depend on flag1
    targets :q3, :q4

    transitions do
      case answer # Use parameters defined in args
      when 'yes'
        target :q3 # Next question, must be defined in targets
      when 'no'
        target :q4
      end
    end
  end

  question :q2 do
    deps :flag1 # Depends on flag1 effect from q1, will be recovered when q1 is answered
  end
end

# Create an applier to calculate flow actions
applier = QFlow.use(rule)

# Calculate which questions to skip and recover
action = applier.apply(:q1, answer: 'yes')
puts action[:skip]    # => ["q2"] - questions to skip
puts action[:recover] # => ["q3"] - questions to recover
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
- **recover**: Questions that should be recovered based on dependencies and effects

## Development

### Run lint

Ensure code quality with RuboCop:

```shell
bundle exec rake rubocop
```

### Run test

Run the test suite to ensure everything works as expected:

```shell
bundle exec rake test
```

### Run build

Build the gem package:

```shell
bundle exec gem build
```
