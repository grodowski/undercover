# frozen_string_literal: true

require 'spec_helper'
require 'undercover'

describe Undercover::Report do
  let(:options) do
    Undercover::Options.new.tap do |opt|
      opt.lcov = 'spec/fixtures/fixtures.lcov'
      opt.path = 'spec/fixtures'
      opt.git_dir = 'test.git'
    end
  end

  let(:changeset) do
    git_dir = File.join(options.path, options.git_dir)
    Undercover::Changeset.new(git_dir, options.compare)
  end
  subject(:report) { described_class.new(changeset, options) }

  it 'builds a report with coverage metrics' do
    report.build

    expect(report.results.size).to eq(2)
    expect(report.all_results.first).to be_an(Undercover::Result)
    expect(report.all_results.first.coverage_f).to eq(0.8333)
  end

  it 'does not parse files outside of the lcov report' do
    allow(Parser::CurrentRuby).to receive(:parse_file).and_call_original
    expect(Parser::CurrentRuby)
      .not_to receive(:parse_file).with('spec/fixtures/no_lcov.rb')

    report.build
  end

  it 'builds pathnames relative to --path' do
    report.build

    expect(report.results.keys.sort).to eq(%w[class.rb module.rb])
  end

  it 'builds warnings does not mess up with result keys' do
    report.build
    report.build_warnings

    expect(report.results.keys.sort).to eq(%w[class.rb module.rb])
  end

  context 'with mock changeset' do
    let(:changeset) do
      mock_changeset = instance_double(Undercover::Changeset)
      allow(mock_changeset).to receive(:update) { mock_changeset }
      allow(mock_changeset)
        .to receive(:each_changed_line)
        .and_yield('test_two_patches.rb', 6)
        .and_yield('test_two_patches.rb', 21)
      mock_changeset
    end

    it 'builds 2 warnings from two patches' do
      options.lcov = 'spec/fixtures/test_two_patches.lcov'
      report.build
      warnings = report.build_warnings.to_a
      expect(warnings.size).to eq(2)
      expect(warnings[0].file_path).to eq('test_two_patches.rb')
      expect(warnings[0].first_line).to eq(3)
      expect(warnings[1].file_path).to eq('test_two_patches.rb')
      expect(warnings[1].first_line).to eq(15)
    end
  end
end
