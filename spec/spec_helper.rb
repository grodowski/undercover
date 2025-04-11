# frozen_string_literal: true

require 'timecop'
require 'pry'

require 'simplecov'
require 'simplecov-lcov'
SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
  [SimpleCov::Formatter::LcovFormatter, SimpleCov::Formatter::HTMLFormatter]
)
SimpleCov.start do
  enable_coverage(:branch)
  add_filter(/^\/spec\//)
end

require 'undercover'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec::Matchers.define :undercover_options do |opts_hash|
  match do |actual|
    opts_hash.all? do |opt_key, opt_value|
      expect(actual.send(opt_key)).to match(opt_value)
    end
  end
end

def stub_stdout
  allow($stdout).to receive(:puts)
end

# Matchers compatible with Imagen::Node::Base#find_all
# TODO: deduplicate with Imagen gem
def of_type(type)
  ->(node) { node.is_a?(type) }
end

def with_name(name)
  ->(node) { node.name == name }
end

def simplecov_coverage_fixture(path)
  allow_any_instance_of(SimpleCov::Result).to receive(:filter!)
  allow_any_instance_of(SimpleCov::Result).to receive(:root) { '/Users/mrgrodo/dev/undercover/' }

  Undercover::SimplecovResultAdapter.parse(File.open(path)).tap do
    allow_any_instance_of(SimpleCov::Result).to receive(:filter!).and_call_original
    allow_any_instance_of(SimpleCov::Result).to receive(:root).and_call_original
  end
end
