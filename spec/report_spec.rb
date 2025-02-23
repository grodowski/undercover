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

    expect(report.results.size).to eq(3)
    all = report.all_results
    expect(all[0]).to be_an(Undercover::Result)
    expect(all[0].coverage_f).to eq(0.8333)

    # does not duplicate namespaces
    expect(
      all.select { |res| res.node.name == 'BaconClass' }.size
    ).to eq(1)

    module_results = report.results['module.rb']
    # only includes changed methods
    expect(module_results.map(&:name))
      .to eq(%w[BaconModule bar baz branch_missed branch_hit foobar]) # TODO: misses top-level methods

    # includes flagged blocks
    module_flagged = module_results.select(&:flagged?)
    expect(module_flagged.size).to eq(2)
    expect(module_flagged[0].node.name).to eq('bar')
    expect(module_flagged[0].coverage_f).to eq(0.0)

    # includes flagged blocks with incomplete branch coverage
    expect(module_flagged[1].node.name).to eq('branch_missed')
    expect(module_flagged[1].coverage_f).to eq(0.0)

    # includes unflagged blocks
    unflagged = (module_results - report.flagged_results).to_a.sort_by(&:name)
    expect(unflagged.size).to eq(4)
    expect(unflagged.map(&:name)).to eq(%w[BaconModule baz branch_hit foobar])
    expect(unflagged[0].name).to eq('BaconModule')
    expect(unflagged[0].coverage_f).to eq(0.875)
    expect(unflagged[1].name).to eq('baz')
    expect(unflagged[1].coverage_f).to eq(1.0)

    # includes blocks at top-level (reproduce https://github.com/grodowski/undercover/issues/135)
    top_level_results = report.results['sinatra.rb'].to_a
    expect(top_level_results.size).to eq(1) # TODO: misses top-level methods
    expect(top_level_results[0].name).to eq('block')
    expect(top_level_results[0].coverage_f).to eq(0.0)
    expect(top_level_results[0].flagged?).to eq(true)
    expect(top_level_results[0].first_line).to eq(2)
    expect(top_level_results[0].last_line).to eq(4)
  end

  it 'does not parse files outside of the lcov report' do
    allow(Parser::CurrentRuby).to receive(:parse_file).and_call_original
    expect(Parser::CurrentRuby)
      .not_to receive(:parse_file).with('spec/fixtures/no_lcov.rb')

    report.build
  end

  it 'builds pathnames relative to --path' do
    report.build

    expect(report.results.keys.sort).to eq(%w[class.rb module.rb sinatra.rb])
  end

  it 'builds does not mess up with result keys' do
    report.build

    expect(report.results.keys.sort).to eq(%w[class.rb module.rb sinatra.rb])
  end

  context 'with mock changeset' do
    let(:changeset) do
      mock_changeset = instance_double(Undercover::Changeset)
      allow(mock_changeset).to receive(:update) { mock_changeset }
      allow(mock_changeset)
        .to receive(:each_changed_line)
        .and_yield('test_two_patches.rb', 6)
        .and_yield('test_two_patches.rb', 21)
        .and_yield('Rakefile', 1)
        .and_yield('.undercover_config', 1) # unparsable, won't appear in the report
      mock_changeset
    end

    it 'flags 2 two results when Rakefile is ignored' do
      options.glob_reject_filters = ['Rakefile']
      options.lcov = 'spec/fixtures/test_two_patches.lcov'
      report.build
      flagged = report.flagged_results
      expect(flagged.size).to eq(2)
      expect(flagged[0].file_path).to eq('test_two_patches.rb')
      expect(flagged[0].first_line).to eq(3)
      expect(flagged[1].file_path).to eq('test_two_patches.rb')
      expect(flagged[1].first_line).to eq(15)
    end

    it 'deprecated build_warnings still works' do
      options.glob_allow_filters = ['*.rb']
      options.lcov = 'spec/fixtures/test_two_patches.lcov'
      report.build
      warnings = report.build_warnings.to_a
      expect(warnings.size).to eq(2)
      expect(warnings[0].file_path).to eq('test_two_patches.rb')
      expect(warnings[0].first_line).to eq(3)
      expect(warnings[1].file_path).to eq('test_two_patches.rb')
      expect(warnings[1].first_line).to eq(15)
    end

    it 'reports changed files that were not in the lcov report' do
      options.lcov = 'spec/fixtures/test_empty.lcov'
      report.build
      warnings = report.build_warnings.to_a
      expect(warnings.size).to eq(3)

      expect(warnings[0].file_path).to eq('test_two_patches.rb')
      expect(warnings[0].first_line).to eq(3)
      expect(warnings[1].file_path).to eq('test_two_patches.rb')
      expect(warnings[1].first_line).to eq(15)
      expect(warnings[2].file_path).to eq('Rakefile')
      expect(warnings[2].first_line).to eq(7)

      expect(warnings[0].coverage_f).to eq(0.0)
      expect(warnings[1].coverage_f).to eq(0.0)
    end
  end
end
