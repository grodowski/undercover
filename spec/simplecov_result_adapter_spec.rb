# frozen_string_literal: true

require 'spec_helper'

require 'undercover'

describe Undercover::SimplecovResultAdapter do
  it 'reports a structure of source files with branch coverage' do
    adapter = simplecov_coverage_fixture('spec/fixtures/nocov.json')

    expect(adapter.simplecov_result['coverage'].count).to eq(1)
    branchful = adapter.coverage('spec/fixtures/nocov.rb')
    expected = [
      [1, 'ignored'],
      [2, 'ignored'],
      [3, 'ignored'],
      [4, 'ignored'],
      [5, 'ignored'],
      [6, 'ignored'],
      [7, 'ignored'],
      [8, 'ignored'],
      [9, 'ignored'],
      [10, 'ignored'],
      [12, 1],
      [13, 0],
      [14, 0],
      [4, 0, 1, 0],
      [6, 0, 2, 1],
    ]
    expect(branchful).to eq(expected)
  end

  it 'raises an error with a malformed JSON' do
    skip
  end

  it 'includes total coverage data' do
    skip
    # parser = described_class.parse('spec/fixtures/fixtures.lcov')

    # expect(parser.total_coverage).to eq(0.875)
    # expect(parser.total_branch_coverage).to eq(0.833)
  end

  it 'returns 0 total coverage for empty files' do
    skip
    # empty_parser = described_class.parse(Tempfile.new.path)

    # expect(empty_parser.total_coverage).to eq(0)
    # expect(empty_parser.total_branch_coverage).to eq(0)
  end
end
