# frozen_string_literal: true

require 'spec_helper'
require 'undercover'
require 'pry'

describe Undercover::Report do
  it 'builds a report with coverage metrics' do
    report = described_class.new(
      'spec/fixtures/fixtures.lcov',
      'spec/fixtures',
      git_dir: 'test.git'
    )

    report.build

    expect(report.results.size).to eq(2)
    expect(report.all_results.first).to be_an(Undercover::Result)
    expect(report.all_results.first.coverage_f).to eq(0.8333)
  end
end
