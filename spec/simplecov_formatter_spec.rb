# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe 'SimpleCov::Formatter::Undercover' do
  let(:lines12) { Array.new(12) { [0, 1, nil].sample } }
  let(:lines7) { Array.new(7) { [0, 1, nil].sample } }
  let(:result) do
    SimpleCov::Result.from_hash(
      'rspec' => {
        'coverage' => {
          'spec/fixtures/file_one' => {'lines' => lines7},
          'spec/fixtures/file_two' => {'lines' => lines12}
        },
        'timestamp' => Time.now.to_i
      }
    ).first
  end
  let(:formatter) { SimpleCov::Formatter::Undercover.new }
  let(:formatted_result) { formatter.format_result(result) }

  before do
    allow_any_instance_of(SimpleCov::Result).to receive(:filter!).and_return(nil)
  end

  it 'includes SimpleCov.root in meta' do
    expect(formatted_result[:meta][:simplecov_root]).to eq(SimpleCov.root)
  end

  it 'uses relative paths as keys' do
    expect(formatted_result[:coverage].keys).to match_array(
      ['spec/fixtures/file_one', 'spec/fixtures/file_two']
    )
  end

  it 'formats coverage data correctly' do
    expect(formatted_result[:coverage]['spec/fixtures/file_one']).to eq(branches: [], lines: lines7)
    expect(formatted_result[:coverage]['spec/fixtures/file_two']).to eq(branches: [], lines: lines12)
  end
end
