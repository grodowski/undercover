# frozen_string_literal: true

require 'spec_helper'

describe Undercover::CLI do
  it 'creates an Undercover::Report with defaults' do
    stub_build
    expect(Undercover::Report)
      .to receive(:new)
      .with(
        a_string_ending_with('coverage/lcov/undercover.lcov'),
        '.',
        git_dir: '.git',
        compare: nil
      )
      .and_call_original
    subject.run([])
  end

  it 'creates an Undercover::Report with options' do
    stub_build
    expect(Undercover::Report)
      .to receive(:new)
      .with(
        'spec/fixtures/sample.lcov',
        'spec/fixtures',
        git_dir: 'test.git',
        compare: nil
      )
      .and_call_original
    subject.run(%w[-lspec/fixtures/sample.lcov -pspec/fixtures -gtest.git])
  end

  it 'accepts --compare' do
    stub_build
    expect(Undercover::Report)
      .to receive(:new)
      .with(
        a_string_ending_with('coverage/lcov/undercover.lcov'),
        '.',
        git_dir: '.git',
        compare: 'HEAD~1'
      )
      .and_call_original
    subject.run(%w[-cHEAD~1])
  end

  it 'returns 0 exit code on success' do
    mock_report = instance_double(Undercover::Report, validate: nil)
    stub_build.and_return(mock_report)

    expect(mock_report).to receive(:build_warnings) { [] }
    expect(subject.run([])).to eq(0)
  end

  it 'returns 1 exit code on warnings' do
    mock_report = instance_double(Undercover::Report, validate: nil)
    stub_build.and_return(mock_report)

    allow(Undercover::Formatter).to receive(:new)

    expect(mock_report).to receive(:build_warnings) { [double] }
    expect(subject.run([])).to eq(1)
  end

  it 'prints changeset validation errors' do
    mock_report = instance_double(Undercover::Report, validate: :stale_coverage)
    stub_build.and_return(mock_report)

    expected_output = Undercover::CLI::WARNINGS_TO_S[:stale_coverage] + "\n"

    expect do
      expect(subject.run([])).to eq(1)
    end.to output(expected_output).to_stdout
  end

  # rubocop:disable Metrics/AbcSize
  def stub_build
    lcov = double
    allow(File).to receive(:open) { lcov }
    allow(Undercover::LcovParser).to receive(:parse).with(lcov)
    allow(Imagen).to receive(:from_local)
    allow_any_instance_of(Undercover::Report).to receive(:validate) { nil }
    allow_any_instance_of(Undercover::Report).to receive(:build) { |rep| rep }
  end
  # rubocop:enable Metrics/AbcSize
end
