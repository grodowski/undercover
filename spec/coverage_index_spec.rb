# frozen_string_literal: true

require 'spec_helper'
require 'undercover'

describe Undercover::CoverageIndex do
  it 'returns tuples on the given lines in report order, lines before branches' do
    file_coverage = [[1, 0], [2, 1], [3, 1], [3, 0, 1, 1], [2, 0, 2, 0]]

    expect(described_class.new(file_coverage).within(2..3))
      .to eq([[2, 1], [3, 1], [3, 0, 1, 1], [2, 0, 2, 0]])
  end

  it 'returns nothing for lines without coverage or an empty range' do
    index = described_class.new([[1, 0]])

    expect(index.within(5..9)).to eq([])
    expect(index.within(2..1)).to eq([])
  end
end
