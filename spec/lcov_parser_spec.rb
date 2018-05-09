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

  it 'passes blank lines' do
    parser = described_class.new(StringIO.new("\n"))

    expect { parser.parse }.not_to raise_error
  end

  it 'raises an error with a malformed LCOV' do
    parser = described_class.new(StringIO.new('baconium!'))

    expect { parser.parse }.to raise_error(Undercover::LcovParseError)
  end
end
