# frozen_string_literal: true

require 'spec_helper'
require 'undercover'
require 'pry'

describe Undercover::Report do
  it 'builds a report with coverage metrics' do
    options = Undercover::Options.new.tap do |opt|
      opt.lcov = 'spec/fixtures/fixtures.lcov'
      opt.path = 'spec/fixtures'
      opt.git_dir = 'test.git'
    end
    report = described_class.new(options)

    # does not parse files outside of the lcov report
    allow(Parser::CurrentRuby).to receive(:parse_file).and_call_original
    expect(Parser::CurrentRuby)
      .not_to receive(:parse_file).with('spec/fixtures/no_lcov.rb')

    report.build

    expect(report.results.size).to eq(2)
    expect(report.all_results.first).to be_an(Undercover::Result)
    expect(report.all_results.first.coverage_f).to eq(0.8333)
  end
end
