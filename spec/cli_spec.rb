# frozen_string_literal: true

require 'spec_helper'

RSpec::Matchers.define_negated_matcher :a_string_excluding, :include

describe Undercover::CLI do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CLAUDECODE').and_return(nil)
    allow(ENV).to receive(:[]).with('UNDERCOVER_NO_HINT').and_return('1')
  end

  it 'creates an Undercover::Report with defaults' do
    stub_stdout
    stub_build

    expect(Undercover::Report)
      .to receive(:new)
      .with(
        instance_of(Undercover::Changeset),
        undercover_options(
          lcov: nil,
          git_dir: '.git',
          compare: nil
        ),
        mock_simplecov_result_adapter
      )
      .and_call_original
    subject.run([])
  end

  it 'creates a commits_only changeset with --commits-only' do
    stub_stdout
    stub_build

    expect(Undercover::Changeset)
      .to receive(:new).with('spec/fixtures/test.git', 'master', commits_only: true).and_call_original
    subject.run(%w[-gspec/fixtures/test.git --compare master --commits-only])
  end

  it 'errors on --commits-only without --compare' do
    stub_build

    expect(Undercover::Changeset).not_to receive(:new)
    expect do
      expect(subject.run(['--commits-only'])).to eq(1)
    end.to output(/--commits-only requires --compare ref/).to_stdout
  end

  it 'reads options from project configuration file' do
    allow_any_instance_of(Undercover::Options)
      .to receive(:project_options_file)
      .and_return('./spec/fixtures/.undercover_config')

    expect(subject)
      .to receive(:run_report)
      .with(
        undercover_options(
          lcov: match('spec/fixtures/sample.lcov'),
          git_dir: '.git',
          compare: nil
        )
      )

    subject.run([])
  end

  it 'allows overriding config with cli args' do
    allow_any_instance_of(Undercover::Options)
      .to receive(:project_options_file)
      .and_return('./spec/fixtures/.undercover_config')

    expect(subject)
      .to receive(:run_report)
      .with(
        undercover_options(
          lcov: match('made_up.lcov'),
          git_dir: '.git',
          compare: nil
        )
      )

    subject.run(['-lmade_up.lcov'])
  end

  it 'creates an Undercover::Report with options' do
    stub_stdout
    stub_build

    expect(Undercover::Report)
      .to receive(:new)
      .with(
        instance_of(Undercover::Changeset),
        undercover_options(
          lcov: 'spec/fixtures/sample.lcov',
          git_dir: 'spec/fixtures/test.git',
          compare: nil
        ),
        mock_simplecov_result_adapter
      )
      .and_call_original
    subject.run(%w[-lspec/fixtures/sample.lcov -gspec/fixtures/test.git])
  end

  it 'accepts --compare' do
    stub_stdout
    stub_build

    expect(Undercover::Report)
      .to receive(:new)
      .with(
        instance_of(Undercover::Changeset),
        undercover_options(
          lcov: nil,
          git_dir: '.git',
          compare: 'HEAD~1'
        ),
        mock_simplecov_result_adapter
      )
      .and_call_original
    subject.run(%w[-cHEAD~1])
  end

  it 'sets file globs from options' do
    stub_stdout
    stub_build

    expect(Undercover::Report)
      .to receive(:new)
      .with(
        instance_of(Undercover::Changeset),
        undercover_options(
          lcov: nil,
          git_dir: '.git',
          compare: nil,
          glob_allow_filters: ['*.rb', '*.rake'],
          glob_reject_filters: ['Rakefile']
        ),
        mock_simplecov_result_adapter
      )
      .and_call_original
    subject.run(%w[-f *.rb,*.rake -x Rakefile])
  end

  it 'returns 0 exit code on success' do
    stub_stdout

    mock_report = report_double
    stub_build.and_return(mock_report)

    expect(mock_report).to receive(:flagged_results) { [] }
    expect(subject.run([])).to eq(0)
  end

  it 'returns 1 exit code on warnings' do
    stub_stdout

    mock_report = report_double
    stub_build.and_return(mock_report)

    expect(mock_report).to receive(:flagged_results) { [double] }
    expect(subject.run([])).to eq(1)
  end

  it 'warns when every candidate file was skipped by the globs' do
    stub_stdout

    mock_report = report_double(globbed_out_files: %w[app/main.rb app/lib/foo.rb])
    stub_build.and_return(mock_report)
    allow(mock_report).to receive(:flagged_results) { [] }

    expect { subject.run([]) }.to output(
      a_string_matching(/nothing was checked - all 2 candidate file\(s\) were skipped/).and(a_string_excluding('ERB'))
    ).to_stderr
  end

  it 'explains that ERB templates are opt-in when the default globs skipped them' do
    stub_stdout
    mock_report = report_double(globbed_out_files: %w[app/views/home.html.erb README.md])
    stub_build.and_return(mock_report)
    allow(mock_report).to receive(:flagged_results) { [] }

    expect { subject.run([]) }
      .to output(a_string_including('1 changed ERB template(s) were skipped because view coverage is opt-in')
        .and(a_string_including("--include-files '*.rb,*.rake,*.ru,Rakefile,*.erb'"))).to_stderr
  end

  it 'blames the globs when ERB templates were included but still skipped' do
    stub_stdout
    mock_report = report_double(globbed_out_files: %w[app/views/home.html.erb])
    stub_build.and_return(mock_report)
    allow(mock_report).to receive(:flagged_results) { [] }

    expect { subject.run(['-f', 'apps/dash/**/*.erb']) }
      .to output(/all 1 candidate file\(s\) were skipped by --include-files/).to_stderr
  end

  it 'warns when ERB templates were skipped for lack of eval coverage' do
    stub_stdout
    mock_report = report_double(results: {'app/main.rb' => Set.new},
                                erb_files_without_coverage: %w[app/views/home.html.erb])
    stub_build.and_return(mock_report)
    allow(mock_report).to receive(:flagged_results) { [] }

    expect { subject.run([]) }
      .to output(/skipped 1 ERB template\(s\) - the coverage report has no ERB coverage/).to_stderr
  end

  it 'does not blame the globs when only ERB templates without coverage were skipped' do
    stub_stdout
    mock_report = report_double(erb_files_without_coverage: %w[app/views/home.html.erb])
    stub_build.and_return(mock_report)
    allow(mock_report).to receive(:flagged_results) { [] }

    expect { subject.run([]) }.to output(
      a_string_including('skipped 1 ERB template(s) - the coverage report has no ERB coverage')
        .and(a_string_excluding('--include-files/--exclude-files'))
    ).to_stderr
  end

  it 'counts only the globbed out files when ERB templates without coverage were skipped too' do
    stub_stdout
    mock_report = report_double(globbed_out_files: %w[.undercover lib/tasks/cases.rake],
                                erb_files_without_coverage: %w[app/views/home.html.erb])
    stub_build.and_return(mock_report)
    allow(mock_report).to receive(:flagged_results) { [] }

    expect { subject.run(['-f', '*.rb,*.erb']) }.to output(
      a_string_matching(/skipped 1 ERB template\(s\).*\n.*besides those ERB templates, 2 candidate file\(s\)/)
        .and(a_string_excluding('nothing was checked'))
    ).to_stderr
  end

  it 'does not warn about globs when there are results to report' do
    stub_stdout

    mock_report = report_double(results: {'app/main.rb' => Set.new}, globbed_out_files: %w[README.md])
    stub_build.and_return(mock_report)
    allow(mock_report).to receive(:flagged_results) { [] }

    expect { subject.run([]) }.not_to output.to_stderr
  end

  describe 'hint' do
    before do
      allow(ENV).to receive(:[]).with('UNDERCOVER_NO_HINT').and_return(nil)
      stub_build.and_return(report_double(flagged_results: []))
    end

    it 'prints the UndercoverCI hint to stderr without changing the exit code' do
      allow(Undercover::Formatter).to receive(:new).and_return(
        instance_double(Undercover::Formatter, to_s: 'report', exit_code: 1)
      )
      expect do
        expect do
          expect(subject.run([])).to eq(1)
        end.to output("#{described_class::HINTS[:undercover_ci]}\n").to_stderr
      end.to output(a_string_excluding('UndercoverCI')).to_stdout
    end

    it 'prints the Claude Code skill hint instead in Claude Code' do
      stub_stdout
      allow(ENV).to receive(:[]).with('CLAUDECODE').and_return('1')
      expect { subject.run([]) }.to output("#{described_class::HINTS[:claude_code]}\n").to_stderr
    end

    it 'does not print the hint with --format json' do
      stub_stdout
      expect { subject.run(%w[--format json]) }.not_to output.to_stderr
    end

    it 'does not print the hint with --no-hint' do
      stub_stdout
      expect { subject.run(%w[--no-hint]) }.not_to output.to_stderr
    end

    it 'does not print the hint with UNDERCOVER_NO_HINT set' do
      stub_stdout
      allow(ENV).to receive(:[]).with('UNDERCOVER_NO_HINT').and_return('1')
      expect { subject.run([]) }.not_to output.to_stderr
    end
  end

  describe '.hint_for' do
    let(:text) { Undercover::Options.new.parse([]) }
    let(:json) { Undercover::Options.new.parse(%w[--format json]) }
    let(:hidden) { Undercover::Options.new.parse(%w[--no-hint]) }

    it 'picks the UndercoverCI hint everywhere outside Claude Code' do
      expect(described_class.hint_for(text, {})).to eq(described_class::HINTS[:undercover_ci])
      expect(described_class.hint_for(text, 'CI' => 'true')).to eq(described_class::HINTS[:undercover_ci])
    end

    it 'picks the Claude Code skill hint in Claude Code' do
      expect(described_class.hint_for(text, 'CLAUDECODE' => '1')).to eq(described_class::HINTS[:claude_code])
      expect(described_class.hint_for(text, 'CLAUDECODE' => '1', 'CI' => 'true'))
        .to eq(described_class::HINTS[:claude_code])
    end

    it 'returns nil with --format json, --no-hint or UNDERCOVER_NO_HINT' do
      expect(described_class.hint_for(json, {})).to be_nil
      expect(described_class.hint_for(hidden, {})).to be_nil
      expect(described_class.hint_for(text, 'UNDERCOVER_NO_HINT' => '1')).to be_nil
      expect(described_class.hint_for(text, 'UNDERCOVER_NO_HINT' => '')).to eq(described_class::HINTS[:undercover_ci])
    end
  end

  it 'prints changeset validation for stale coverage' do
    mock_report = instance_double(Undercover::Report, validate: :stale_coverage)
    stub_build.and_return(mock_report)

    expected_output = "#{Undercover::Formatter::WARNINGS_TO_S[:stale_coverage]}\n"

    expect do
      expect(subject.run([])).to eq(0)
    end.to output(a_string_starting_with(expected_output)).to_stdout
  end

  it 'prints changeset validation for no changes' do
    mock_report = instance_double(Undercover::Report, validate: :no_changes)
    stub_build.and_return(mock_report)

    expected_output = "#{Undercover::Formatter::WARNINGS_TO_S[:no_changes]}\n"

    expect do
      expect(subject.run([])).to eq(0)
    end.to output(expected_output).to_stdout
  end

  it 'outputs JSON when --format json is used' do
    mock_report = report_double
    stub_build.and_return(mock_report)

    expect(mock_report).to receive(:flagged_results) { [] }

    expect do
      expect(subject.run(['--format', 'json'])).to eq(0)
    end.to output(/\{\s*"warnings":\s*\[\]/).to_stdout
  end

  it 'prints how long the run took when timed' do
    stub_build.and_return(report_double(flagged_results: []))

    expect do
      expect(subject.run([], timed: true)).to eq(0)
    end.to output(/No coverage is missing.*\nUndercover finished in \d+(\.\d+)?s\n\z/m).to_stdout
  end

  it 'does not print the timing after JSON output' do
    stub_build.and_return(report_double(flagged_results: []))

    expect do
      expect(subject.run(['--format', 'json'], timed: true)).to eq(0)
    end.to output(satisfy { JSON.parse(_1) }).to_stdout
  end

  it 'sets max_warnings_limit from options' do
    stub_stdout
    stub_build

    expect(Undercover::Report)
      .to receive(:new)
      .with(
        instance_of(Undercover::Changeset),
        undercover_options(
          lcov: nil,
          git_dir: '.git',
          compare: nil,
          max_warnings_limit: 5
        ),
        mock_simplecov_result_adapter
      )
      .and_call_original
    subject.run(%w[-w 5])
  end

  it 'sets max_warnings_limit from long option' do
    stub_stdout
    stub_build

    expect(Undercover::Report)
      .to receive(:new)
      .with(
        instance_of(Undercover::Changeset),
        undercover_options(
          lcov: nil,
          git_dir: '.git',
          compare: nil,
          max_warnings_limit: 10
        ),
        mock_simplecov_result_adapter
      )
      .and_call_original
    subject.run(%w[--max-warnings 10])
  end

  it 'exits with help text when --help is used' do
    expect do
      expect { subject.run(['--help']) }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(0)
      end
    end.to output(a_string_including('Usage:')).to_stdout
  end

  it 'exits with version when --version is used' do
    expect do
      expect { subject.run(['--version']) }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(0)
      end
    end.to output(a_string_including(Undercover::VERSION)).to_stdout
  end

  it 'uses simplecov resultset when provided' do
    stub_stdout
    allow_any_instance_of(Undercover::Options).to receive(:guess_resultset_path)

    lcov = double
    json_file = StringIO.new('{"coverage": {}}')
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('test.json').and_return(true)
    allow(File).to receive(:exist?).with('./.undercover').and_return(false)
    allow(File).to receive(:open).with('test.lcov') { lcov }
    allow(File).to receive(:open).with('test.json') { json_file }
    allow(Undercover::LcovParser).to receive(:parse).with(lcov, instance_of(Undercover::Options),
                                                          hash_including(only_files: anything)) do
      double(coverage: [])
    end
    allow_any_instance_of(Undercover::Report).to receive(:validate) { nil }
    allow_any_instance_of(Undercover::Report).to receive(:build) { |rep| rep }
    allow_any_instance_of(Undercover::Report).to receive(:flagged_results) { [] }

    expect(Undercover::SimplecovResultAdapter)
      .to receive(:parse).with(json_file, instance_of(Undercover::Options), hash_including(only_files: anything))
      .and_return(double(coverage: [], ignored_files: [], coverage_keys: [], simplecov_root: nil,
                         coverage_root: Undercover::CoverageRoot::NONE, :coverage_root= => nil, :erb_coverage? => true))

    subject.run(['-l', 'test.lcov', '-s', 'test.json'])
  end

  it 'creates changeset with SimpleCov ignored files' do
    stub_stdout
    allow_any_instance_of(Undercover::Options).to receive(:guess_resultset_path)

    json_content = {
      'meta' => {
        'ignored_files' => [{'string' => 'app/lib/temp/'}, {'file' => 'db/migrate/migration.rb'}]
      },
      'coverage' => {
        'app/models/user.rb' => {'lines' => [1, 0]}
      }
    }.to_json
    json_file = StringIO.new(json_content)

    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('test.json').and_return(true)
    allow(File).to receive(:exist?).with('./.undercover').and_return(false)
    allow(File).to receive(:open).with('test.json') { json_file }

    simplecov_adapter = double('SimpleCov adapter',
                               coverage_keys: [],
                               simplecov_root: nil,
                               coverage_root: Undercover::CoverageRoot::NONE,
                               :coverage_root= => nil, :erb_coverage? => true,
                               coverage: [],
                               ignored_files: [{'string' => 'app/lib/temp/'},
                                               {'file' => 'db/migrate/migration.rb'}])
    allow(Undercover::SimplecovResultAdapter).to receive(:parse).and_return(simplecov_adapter)

    allow_any_instance_of(Undercover::Report).to receive(:validate) { nil }
    allow_any_instance_of(Undercover::Report).to receive(:build) { |rep| rep }
    allow_any_instance_of(Undercover::Report).to receive(:flagged_results) { [] }

    expect(Undercover::FilterSet).to receive(:new).with(
      ['*.rb', '*.rake', '*.ru', 'Rakefile'],
      ['test/*', 'spec/*', 'db/*', 'config/*', '*_test.rb', '*_spec.rb', 'vendor/*'],
      [{'string' => 'app/lib/temp/'}, {'file' => 'db/migrate/migration.rb'}],
      coverage_root: Undercover::CoverageRoot::NONE
    ).once.and_call_original

    subject.run(['-s', 'test.json'])
  end

  it 'passes nil only_files to the adapter when the changeset has no changed files' do
    stub_stdout
    stub_build
    allow_any_instance_of(Undercover::Changeset).to receive(:file_paths).and_return([])

    expect(Undercover::SimplecovResultAdapter)
      .to receive(:parse)
      .with(anything, instance_of(Undercover::Options), hash_including(only_files: nil))
      .and_return(mock_simplecov_result_adapter)

    subject.run([])
  end

  it 'parses lcov report and passes it to the report builder' do
    stub_stdout

    allow_any_instance_of(Undercover::Options).to receive(:guess_resultset_path)
    allow_any_instance_of(Undercover::Report).to receive(:validate) { nil }
    allow_any_instance_of(Undercover::Report).to receive(:build) { |rep| rep }
    allow_any_instance_of(Undercover::Report).to receive(:flagged_results) { [] }
    expect(Undercover::LcovParser).to receive(:parse) { mock_lcov_parser }
    expect(Undercover::Report)
      .to receive(:new)
      .with(
        instance_of(Undercover::Changeset),
        undercover_options(
          lcov: 'spec/fixtures/sample.lcov',
          git_dir: '.git',
          compare: nil
        ),
        mock_lcov_parser
      )
      .and_call_original

    subject.run(['-l', 'spec/fixtures/sample.lcov'])
  end

  it 'returns 1 exit code when no coverage report found' do
    allow_any_instance_of(Undercover::Options).to receive(:guess_resultset_path)
    allow_any_instance_of(Undercover::Options).to receive(:guess_lcov_path)
    allow(File).to receive(:exist?).with('./.undercover').and_return(false)

    expected_output = a_string_matching(/❌ ERROR: No coverage report found/)

    expect do
      expect(subject.run([])).to eq(1)
    end.to output(expected_output).to_stdout
  end

  it 'returns 1 exit code when coverage file does not exist' do
    allow_any_instance_of(Undercover::Options).to receive(:guess_resultset_path)
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('./.undercover').and_return(false)
    allow(File).to receive(:exist?).with('nonexistent.lcov').and_return(false)

    expected_output = a_string_matching(/❌ ERROR: Coverage report not found at: nonexistent.lcov/)

    expect do
      expect(subject.run(['-l', 'nonexistent.lcov'])).to eq(1)
    end.to output(expected_output).to_stdout
  end

  it 'shows default paths when no coverage report found' do
    allow_any_instance_of(Undercover::Options).to receive(:guess_resultset_path)
    allow_any_instance_of(Undercover::Options).to receive(:guess_lcov_path)
    allow(File).to receive(:exist?).with('./.undercover').and_return(false)

    expected_output = a_string_matching(/Checked default paths:.*coverage\/coverage\.json.*coverage\/lcov/m)

    expect do
      expect(subject.run([])).to eq(1)
    end.to output(expected_output).to_stdout
  end

  def report_double(**attrs)
    instance_double(
      Undercover::Report,
      validate: nil, results: {}, globbed_out_files: [], erb_files_without_coverage: [], **attrs
    )
  end

  let(:mock_simplecov_result_adapter) do
    instance_double(
      Undercover::SimplecovResultAdapter,
      coverage: [], ignored_files: [], coverage_keys: [], simplecov_root: nil,
      coverage_root: Undercover::CoverageRoot::NONE, :coverage_root= => nil, :erb_coverage? => true
    )
  end
  let(:mock_lcov_parser) do
    instance_double(
      Undercover::LcovParser,
      coverage: [], ignored_files: [], coverage_keys: [], simplecov_root: nil,
      coverage_root: Undercover::CoverageRoot::NONE, :coverage_root= => nil, :erb_coverage? => true
    )
  end

  def stub_build # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    file_stub = double('file', read: '{"coverage": {}}', each: nil)
    allow_any_instance_of(Undercover::Options).to receive(:guess_resultset_path) do |opts|
      opts.simplecov_resultset = 'coverage/coverage.json'
    end
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('coverage/coverage.json').and_return(true)
    allow(File).to receive(:exist?).with('./.undercover').and_return(false)
    allow(File).to receive(:open) { file_stub }
    allow(Undercover::SimplecovResultAdapter).to receive(:parse).with(file_stub, instance_of(Undercover::Options),
                                                                      hash_including(only_files: anything)) do
      mock_simplecov_result_adapter
    end
    allow(Undercover::LcovParser).to receive(:parse).with(file_stub, instance_of(Undercover::Options),
                                                          hash_including(only_files: anything)) do
      mock_lcov_parser
    end
    allow_any_instance_of(Undercover::Report).to receive(:validate) { nil }
    allow_any_instance_of(Undercover::Report).to receive(:build) { |rep| rep }
  end
end
