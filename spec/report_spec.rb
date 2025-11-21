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
  subject(:report) { described_class.new(changeset, options, lcov_from_options(options)) }

  context 'with SimpleCov resultset' do
    let(:options_with_simplecov) do
      Undercover::Options.new.tap do |opt|
        opt.path = 'spec/fixtures'
        opt.git_dir = 'test.git'
        opt.simplecov_resultset = 'spec/fixtures/nocov.json'
      end
    end

    it 'initializes with SimpleCov resultset adapter' do
      simplecov_adapter = double('SimpleCov adapter', coverage: [], ignored_files: [])

      expect(Undercover::LcovParser).not_to receive(:parse)

      described_class.new(changeset, options_with_simplecov, simplecov_adapter)
    end

    context 'with ignored files' do
      let(:options_with_simplecov) do
        Undercover::Options.new.tap do |opt|
          opt.path = 'spec/fixtures'
          opt.git_dir = 'test.git'
          opt.simplecov_resultset = 'spec/fixtures/simplecov_with_ignored_files.json'
        end
      end

      subject(:report) do
        described_class.new(changeset, options_with_simplecov, simplecov_from_options(options_with_simplecov))
      end

      it 'creates FilterSet with expected ignored files' do
        expected_simplecov_filters = [
          {'string' => 'app/lib/temp/'},
          {'regex' => '/migrate/'},
          {'file' => 'test/factories/user_factory.rb'},
        ]
        expect(report.filter_set.simplecov_filters).to match_array(expected_simplecov_filters)
      end

      it 'uses simplecov filters to ignore files' do
        expect(report.filter_set.include?('class.rb')).to be true
        expect(report.filter_set.include?('app/lib/temp/temp_file.rb')).to be false
      end
    end
  end

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
      .to eq(%w[BaconModule bar baz branch_missed branch_hit foobar lonely_method])

    # includes flagged blocks
    module_flagged = module_results.select(&:flagged?)
    expect(module_flagged.size).to eq(3)
    expect(module_flagged[0].node.name).to eq('bar')
    expect(module_flagged[0].coverage_f).to eq(0.0)

    # includes flagged blocks with incomplete branch coverage
    expect(module_flagged[1].node.name).to eq('branch_missed')
    expect(module_flagged[1].coverage_f).to eq(0.0)

    # includes method at top-level
    expect(module_flagged[2].node.name).to eq('lonely_method')
    expect(module_flagged[2].coverage_f).to eq(0.0)

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
    expect(top_level_results.size).to eq(1)
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
      allow(mock_changeset)
        .to receive(:each_changed_line)
        .and_yield('test_two_patches.rb', 6)
        .and_yield('test_two_patches.rb', 21)
        .and_yield('Rakefile', 1)
        .and_yield('.undercover_config', 1) # unparsable, won't appear in the report
      allow(mock_changeset).to receive(:filter_with)
      mock_changeset
    end

    it 'deprecated build_warnings still works' do
      options.glob_allow_filters = ['*.rb']
      options.lcov = 'spec/fixtures/test_two_patches.lcov'
      report.build
      warnings = report.build_warnings.to_a
      expect(warnings.size).to eq(3)
      expect(warnings[0].file_path).to eq('test_two_patches.rb')
      expect(warnings[0].first_line).to eq(3)
      expect(warnings[1].file_path).to eq('test_two_patches.rb')
      expect(warnings[1].first_line).to eq(15)
    end

    it 'respects max_warnings_limit' do
      options.glob_reject_filters = ['Rakefile']
      options.lcov = 'spec/fixtures/test_two_patches.lcov'
      options.max_warnings_limit = 1
      report.build
      flagged = report.flagged_results
      expect(flagged.size).to eq(1)
      expect(flagged[0].file_path).to eq('test_two_patches.rb')
      expect(flagged[0].first_line).to eq(3)
    end

    it 'stops processing when max_warnings_limit is reached' do
      # Use a changeset that would yield more than 1 flaggable result
      options.glob_allow_filters = ['*.rb']
      options.lcov = 'spec/fixtures/test_two_patches.lcov'
      options.max_warnings_limit = 1

      # Track how many times each_changed_line yields by counting calls
      call_count = 0
      allow(changeset).to receive(:each_changed_line) do |&block|
        [
          ['test_two_patches.rb', 6],
          ['test_two_patches.rb', 21],
          ['test_two_patches.rb', 25], # This should not be processed due to limit
        ].each do |filepath, line_no|
          call_count += 1
          block.call(filepath, line_no)
          # The break should happen after first flag, so this shouldn't reach 3
        end
      end

      report.build
      flagged = report.flagged_results
      expect(flagged.size).to eq(1)
      expect(call_count).to eq(2)
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

  context 'with monorepo-like LCOV fixtures' do
    let(:options) do
      Undercover::Options.new.tap do |opt|
        opt.lcov = 'spec/fixtures/monorepo/app/coverage/app.lcov'
        opt.path = 'spec/fixtures/monorepo'
        opt.git_dir = 'monorepo.git'
        opt.glob_allow_filters = ['*.rb']
      end
    end

    let(:changeset) do
      git_dir = File.join(options.path, options.git_dir)
      Undercover::Changeset.new(git_dir, options.compare)
    end
    subject(:report) { described_class.new(changeset, options, lcov_from_options(options)) }

    it 'matches the paths relative to where undercover runs' do
      # simulate running undercover in the subdirectory
      allow(Dir).to receive(:pwd).and_return('/users/john/spec/fixtures/monorepo/app')
      allow(File).to receive(:expand_path).and_call_original
      allow(File).to receive(:expand_path).with('spec/fixtures/monorepo') { |path| "/users/john/#{path}" }

      report.build

      expect(report.results.keys.sort).to eq(
        %w[app/lib/foo_lib.rb app/main.rb]
      )
      warnings = report.build_warnings.to_a
      expect(warnings.size).to eq(1)
      expect(warnings[0].file_path).to eq('app/lib/foo_lib.rb')
      expect(warnings[0].first_line).to eq(10)
      expect(warnings[0].coverage_f).to eq(0.6)
    end
  end

  context 'with monorepo-like JSON fixtures' do
    let(:options) do
      Undercover::Options.new.tap do |opt|
        opt.simplecov_resultset = 'spec/fixtures/monorepo/app/coverage/app.json'
        opt.path = 'spec/fixtures/monorepo'
        opt.git_dir = 'monorepo.git'
        opt.glob_allow_filters = ['*.rb']
        opt.glob_reject_filters = []
      end
    end

    let(:changeset) do
      git_dir = File.join(options.path, options.git_dir)
      Undercover::Changeset.new(git_dir, options.compare)
    end
    subject(:report) { described_class.new(changeset, options, simplecov_from_options(options)) }

    it 'matches and ignores paths relative to where undercover runs' do
      allow(Dir).to receive(:pwd).and_return('/users/john/spec/fixtures/monorepo/app')
      allow(File).to receive(:expand_path).and_call_original
      allow(File).to receive(:expand_path).with('spec/fixtures/monorepo') { |path| "/users/john/#{path}" }

      report.build

      result_paths = report.results.keys.sort
      # changeset files are ignored correctly with {"string" => "/vendor/bundle/"} and {"regex" => "^\/db/"}
      expect(result_paths).to eq(%w[app/lib/foo_lib.rb app/main.rb])

      warnings = report.build_warnings.to_a
      expect(warnings.size).to eq(1)
      expect(warnings[0].file_path).to eq('app/lib/foo_lib.rb')
      expect(warnings[0].first_line).to eq(10)
      expect(warnings[0].coverage_f).to eq(0.6)
    end

    # TODO: allow specifying a SimpleCov.root in the options instead?
    it 'matches the paths relative to --simplecov-root' do
      skip
    end
  end

  context 'without SimpleCov resultset' do
    let(:options_without_simplecov) do
      Undercover::Options.new.tap do |opt|
        opt.lcov = 'spec/fixtures/fixtures.lcov'
        opt.path = 'spec/fixtures'
        opt.git_dir = 'test.git'
      end
    end
    subject(:report) do
      described_class.new(changeset, options_without_simplecov, lcov_from_options(options_without_simplecov))
    end

    it 'creates FilterSet with empty ignored files' do
      expect(report.filter_set.simplecov_filters).to eq([])
    end

    it 'behaves like the original implementation' do
      expect(report.filter_set.include?('class.rb')).to be true
      expect(report.filter_set.include?('app/lib/temp/temp_file.rb')).to be true
    end
  end

  def lcov_from_options(opts)
    Undercover::LcovParser.parse(File.open(opts.lcov), opts)
  end

  def simplecov_from_options(opts)
    Undercover::SimplecovResultAdapter.parse(File.open(opts.simplecov_resultset), opts)
  end
end
