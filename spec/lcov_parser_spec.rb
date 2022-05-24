# frozen_string_literal: true

require 'spec_helper'

require 'undercover'

describe Undercover::LcovParser do
  it 'reports a structure of source files with line coverage' do
    parser = described_class.parse('spec/fixtures/sample.lcov')

    expect(parser.source_files.count).to eq(3)

    first = parser.source_files.first
    expect(first[0]).to eq('lib/imagen.rb')
    expect(first[1]).to eq([[3, 1], [5, 1], [6, 1], [7, 1], [15, 0], [18, 1]])

    second = parser.source_files['lib/imagen/clone.rb']
    expect(second).to eq([[3, 1], [5, 1], [7, 1], [27, 0], [28, 0], [29, 0]])
  end

  it 'reports a structure of source files with branch coverage' do
    parser = described_class.parse('spec/fixtures/fixtures.lcov')

    expect(parser.source_files.count).to eq(2)
    branchless = parser.source_files['class.rb']
    expected = [
      [3, 1], [4, 12], [5, 4], [6, 54], [8, 1], [9, 0], [10, 1],
      [12, 1], [13, 44], [14, 0], [15, 7], [16, 2], [17, 1], [18, 1]
    ]
    expect(branchless).to eq(expected)
    branchful = parser.source_files['module.rb']
    expected = [
      [3, 1], [4, 1], [5, 1], [8, 1], [9, 0], [12, 1], [13, 1], [16, 1], [17, 1],
      [20, 1], [21, 1], [24, 1], [25, 1], [26, 1], [28, 1], [29, 1], [17, 0, 2, 1],
      [17, 0, 1, 0], [21, 0, 2, 1], [21, 0, 1, 1], [25, 0, 1, 1], [27, 0, 2, 1]
    ]
    expect(branchful).to eq(expected)
  end

  it 'passes blank lines' do
    parser = described_class.new(StringIO.new("\n"))

    expect { parser.parse }.not_to raise_error
  end

  it 'raises an error with a malformed LCOV' do
    parser = described_class.new(StringIO.new('baconium!'))

    expect { parser.parse }.to raise_error(Undercover::LcovParseError)
  end

  it 'includes total coverage data' do
    parser = described_class.parse('spec/fixtures/fixtures.lcov')

    expect(parser.total_coverage).to eq(0.9)
    expect(parser.total_branch_coverage).to eq(0.833)
  end

  it 'returns 0 total coverage for empty files' do
    empty_parser = described_class.parse(Tempfile.new.path)

    expect(empty_parser.total_coverage).to eq(0)
    expect(empty_parser.total_branch_coverage).to eq(0)
  end
end
