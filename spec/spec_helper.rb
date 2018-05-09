# frozen_string_literal: true

require 'bundler/setup'
require 'undercover'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Matchers compatible with Imagen::Node::Base#find_all
# TODO: deduplicate with Imagen gem
def of_type(type)
  ->(node) { node.is_a?(type) }
end

def with_name(name)
  ->(node) { node.name == name }
end
