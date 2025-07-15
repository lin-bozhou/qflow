# frozen_string_literal: true

require_relative 'lib/qflow/version'

# noinspection RubyArgCount
Gem::Specification.new do |spec|
  spec.name = 'qflow'
  spec.version = QFlow::VERSION
  spec.authors = ['Bozhou Lin']
  spec.email = ['lin.bozhou@donuts.ne.jp']
  spec.summary = 'A Ruby DSL for defining questionnaire flow logic'
  spec.description = 'QFlow provides a clean DSL for defining complex questionnaire flows with conditional logic, ' \
                     'dependencies, and automatic skip/recovery calculations'
  spec.homepage = 'https://example.com'
  spec.license = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'
  spec.require_paths = ['lib']
  spec.files = Dir.chdir(__dir__) do
    Dir['exe/**/*', 'lib/**/*', 'README*', 'LICENSE*', '*.gemspec'].reject { File.directory?(_1) }
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { File.basename(_1) }

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://example.com'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
