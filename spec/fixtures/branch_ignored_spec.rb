# Commented out, this spec is only used to generate branch_ignored_coverage/branch_ignored_test.json
# and we don't want to pollute global SimpleCov state in the test suite.

# require 'rspec'
# require 'simplecov'

# SimpleCov.start do
#   enable_coverage(:branch)
#   add_filter(/^\/spec\//)
#   coverage_dir('branch_ignored_coverage')
# end

# require 'undercover/simplecov_formatter'

# SimpleCov::Formatter::Undercover.output_filename = 'branch_ignored_test.json'
# SimpleCov.formatter = SimpleCov::Formatter::Undercover

# require_relative './branch_ignored'

# RSpec.describe '#test_branch_ignored' do
#   it 'works' do
#     expect(test_branch_ignored(:arg1)).to eq(:sym1)
#   end
# end
