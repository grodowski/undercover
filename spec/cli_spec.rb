# frozen_string_literal: true

require 'spec_helper'

describe Undercover::CLI do
  it 'creates an Undercover::Report with defaults' do
    stub_stdout
    stub_build

    expect(Undercover::Report)
      .to receive(:new)
      .with(
        instance_of(Undercover::Changeset),
        undercover_options(
          lcov: a_string_matching(/coverage\/lcov\/\w+\.lcov/),
          path: '.',
          git_dir: '.git',
          compare: nil
        )
      )
      .and_call_original
    subject.run([])
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
          path: '.',
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
          path: '.',
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
          path: 'spec/fixtures',
          git_dir: 'test.git',
          compare: nil
        )
      )
      .and_call_original
    subject.run(%w[-lspec/fixtures/sample.lcov -pspec/fixtures -gtest.git])
  end

  it 'accepts --compare' do
    stub_stdout
    stub_build
    expect(Undercover::Report)
      .to receive(:new)
      .with(
        instance_of(Undercover::Changeset),
        undercover_options(
          lcov: a_string_matching(/coverage\/lcov\/\w+\.lcov/),
          path: '.',
          git_dir: '.git',
          compare: 'HEAD~1'
        )
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
          lcov: a_string_matching(/coverage\/lcov\/\w+\.lcov/),
          path: '.',
          git_dir: '.git',
          compare: nil,
          glob_allow_filters: ['*.rb', '*.rake'],
          glob_reject_filters: ['Rakefile']
        )
      )
      .and_call_original
    subject.run(%w[-f *.rb,*.rake -x Rakefile])
  end

  it 'returns 0 exit code on success' do
    stub_stdout

    mock_report = instance_double(Undercover::Report, validate: nil)
    stub_build.and_return(mock_report)

    expect(mock_report).to receive(:flagged_results) { [] }
    expect(subject.run([])).to eq(0)
  end

  it 'returns 1 exit code on warnings' do
    stub_stdout

    mock_report = instance_double(Undercover::Report, validate: nil)
    stub_build.and_return(mock_report)

    allow(Undercover::Formatter).to receive(:new)

    expect(mock_report).to receive(:flagged_results) { [double] }
    expect(subject.run([])).to eq(1)
  end

  it 'prints changeset validation for stale coverage' do
    mock_report = instance_double(Undercover::Report, validate: :stale_coverage)
    stub_build.and_return(mock_report)

    expected_output = "#{Undercover::CLI::WARNINGS_TO_S[:stale_coverage]}\n"

    allow(Undercover::Formatter).to receive(:new)
    expect(mock_report).to receive(:flagged_results) { [] }

    expect do
      expect(subject.run([])).to eq(0)
    end.to output(a_string_starting_with(expected_output)).to_stdout
  end

  it 'prints changeset validation for no changes' do
    mock_report = instance_double(Undercover::Report, validate: :no_changes)
    stub_build.and_return(mock_report)

    expected_output = "#{Undercover::CLI::WARNINGS_TO_S[:no_changes]}\n"

    expect do
      expect(subject.run([])).to eq(0)
    end.to output(expected_output).to_stdout
  end

  it 'sets ruby syntax version from options' do
    stub_stdout
    stub_build

    v_default = Imagen.parser_version

    subject.run(['-r ruby23'])
    expect(Imagen.parser_version).to eq('ruby23')

    subject.run(%w[--ruby-syntax ruby26])
    expect(Imagen.parser_version).to eq('ruby26')

    Imagen.parser_version = v_default
  end

  it 'sets max_warnings_limit from options' do
    stub_stdout
    stub_build
    expect(Undercover::Report)
      .to receive(:new)
      .with(
        instance_of(Undercover::Changeset),
        undercover_options(
          lcov: a_string_matching(/coverage\/lcov\/\w+\.lcov/),
          path: '.',
          git_dir: '.git',
          compare: nil,
          max_warnings_limit: 5
        )
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
          lcov: a_string_matching(/coverage\/lcov\/\w+\.lcov/),
          path: '.',
          git_dir: '.git',
          compare: nil,
          max_warnings_limit: 10
        )
      )
      .and_call_original
    subject.run(%w[--max-warnings 10])
  end

  it 'exits with help text when --help is used' do
    expect { subject.run(['--help']) }.to raise_error(SystemExit) do |error|
      expect(error.status).to eq(0)
    end
  end

  it 'exits with version when --version is used' do
    expect { subject.run(['--version']) }.to raise_error(SystemExit) do |error|
      expect(error.status).to eq(0)
    end
  end

  it 'uses simplecov resultset when provided' do
    stub_stdout
    allow_any_instance_of(Undercover::Options).to receive(:guess_resultset_path)

    lcov = double
    json_file = StringIO.new('{"coverage": {}}')
    allow(File).to receive(:open).with('test.lcov') { lcov }
    allow(File).to receive(:open).with('test.json') { json_file }
    allow(Undercover::LcovParser).to receive(:parse).with(lcov, instance_of(Undercover::Options)) do
      double(coverage: [])
    end
    allow_any_instance_of(Undercover::Report).to receive(:validate) { nil }
    allow_any_instance_of(Undercover::Report).to receive(:build) { |rep| rep }
    allow_any_instance_of(Undercover::Report).to receive(:flagged_results) { [] }

    expect(Undercover::SimplecovResultAdapter).to receive(:parse).with(json_file, instance_of(Undercover::Options))

    subject.run(['-l', 'test.lcov', '-s', 'test.json'])
  end

  def stub_build # rubocop:disable Metrics/AbcSize
    lcov = double
    allow_any_instance_of(Undercover::Options).to receive(:guess_resultset_path)
    allow(File).to receive(:open) { lcov }
    allow(Undercover::LcovParser).to receive(:parse).with(lcov, instance_of(Undercover::Options)) do
      double(coverage: [])
    end
    allow_any_instance_of(Undercover::Report).to receive(:validate) { nil }
    allow_any_instance_of(Undercover::Report).to receive(:build) { |rep| rep }
  end
end
