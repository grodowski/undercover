# frozen_string_literal: true

require 'spec_helper'

require 'undercover'

describe Undercover::SimplecovResultAdapter do
  it 'reports a structure of source files with branch coverage' do
    adapter = simplecov_coverage_fixture('spec/fixtures/nocov.json')

    expect(adapter.simplecov_result['coverage'].count).to eq(1)
    branchful = adapter.coverage('spec/fixtures/nocov.rb')
    expected = [[1, 'ignored'],
                [2, 'ignored'],
                [3, 'ignored'],
                [4, 'ignored'],
                [5, 'ignored'],
                [6, 'ignored'],
                [7, 'ignored'],
                [8, 'ignored'],
                [9, 'ignored'],
                [10, 'ignored'],
                [12, 1],
                [13, 0],
                [14, 0],
                [15, 1],
                [16, 'ignored'],
                [17, 'ignored'],
                [18, 'ignored'],
                [4, 0, 1, 0],
                [6, 0, 2, 1],
                [13, 0, 3, 0],
                [15, 0, 4, 'ignored']]
    expect(branchful).to eq(expected)
  end

  it 'raises an error with a malformed JSON' do
    skip
  end

  it 'includes total coverage data' do
    skip
    # parser = described_class.parse('spec/fixtures/fixtures.lcov')

    # expect(parser.total_coverage).to eq(0.875)
    # expect(parser.total_branch_coverage).to eq(0.833)
  end

  it 'returns 0 total coverage for empty files' do
    skip
    # empty_parser = described_class.parse(Tempfile.new.path)

    # expect(empty_parser.total_coverage).to eq(0)
    # expect(empty_parser.total_branch_coverage).to eq(0)
  end

  describe '.parse' do
    it 'parses JSON file and returns adapter instance' do
      json_content = {
        'coverage' => {
          'test.rb' => {'lines' => [1, 0], 'branches' => []}
        }
      }.to_json
      file = StringIO.new(json_content)

      adapter = described_class.parse(file)
      expect(adapter).to be_a(described_class)
      expect(adapter.simplecov_result['coverage']).to have_key('test.rb')
    end

    it 'parses JSON file with options' do
      json_content = {
        'coverage' => {
          'test.rb' => {'lines' => [1, 0], 'branches' => []}
        }
      }.to_json
      file = StringIO.new(json_content)
      opts = double('options', path: '/test/path')

      adapter = described_class.parse(file, opts)
      expect(adapter).to be_a(described_class)
      expect(adapter.simplecov_result['coverage']).to have_key('test.rb')
      expect(adapter.instance_variable_get(:@code_dir)).to eq('/test/path')
    end

    it 'raises error for empty JSON' do
      file = StringIO.new('{}')
      expect { described_class.parse(file) }.to raise_error(ArgumentError, 'empty SimpleCov')
    end

    it 'handles real file parsing with JSON.parse and file.read' do
      json_content = {
        'coverage' => {
          'real_test.rb' => {'lines' => [1, 1, 0], 'branches' => []}
        }
      }.to_json

      file = double('file')
      expect(file).to receive(:read).and_return(json_content)

      adapter = described_class.parse(file)
      expect(adapter).to be_a(described_class)
      expect(adapter.simplecov_result['coverage']).to have_key('real_test.rb')
    end
  end

  describe '#initialize' do
    it 'sets simplecov_result and code_dir with opts' do
      result = {'coverage' => {}}
      opts = double(path: '/some/path')
      adapter = described_class.new(result, opts)

      expect(adapter.simplecov_result).to eq(result)
      expect(adapter.instance_variable_get(:@code_dir)).to eq('/some/path')
    end

    it 'handles nil opts' do
      result = {'coverage' => {}}
      adapter = described_class.new(result, nil)

      expect(adapter.simplecov_result).to eq(result)
      expect(adapter.instance_variable_get(:@code_dir)).to be_nil
    end
  end

  describe '#coverage' do
    let(:adapter) do
      result = {
        'coverage' => {
          'test.rb' => {
            'lines' => [1, 0, nil, 1],
            'branches' => [
              {'start_line' => 1, 'coverage' => 1},
              {'start_line' => 2, 'coverage' => 0},
            ]
          }
        }
      }
      described_class.new(result, nil)
    end

    it 'returns empty array for non-existent file' do
      expect(adapter.coverage('nonexistent.rb')).to eq([])
    end

    it 'returns lines and branches coverage' do
      coverage = adapter.coverage('test.rb')
      expected = [
        [1, 1],
        [2, 0],
        [4, 1],
        [1, 0, 1, 1],
        [2, 0, 2, 0],
      ]
      expect(coverage).to eq(expected)
    end

    it 'returns only line coverage when branches are not present' do
      result = {
        'coverage' => {
          'test_no_branches.rb' => {
            'lines' => [1, 0, 'ignored', 1]
          }
        }
      }
      adapter = described_class.new(result, nil)
      coverage = adapter.coverage('test_no_branches.rb')
      expected = [
        [1, 1],
        [2, 0],
        [3, 'ignored'],
        [4, 1],
      ]
      expect(coverage).to eq(expected)
    end
  end

  describe '#skipped?' do
    let(:adapter) do
      result = {
        'coverage' => {
          'test.rb' => {
            'lines' => [1, 'ignored', 0]
          }
        }
      }
      described_class.new(result, nil)
    end

    it 'returns false for non-existent file' do
      expect(adapter.skipped?('nonexistent.rb', 1)).to be false
    end

    it 'returns true for ignored lines' do
      expect(adapter.skipped?('test.rb', 2)).to be true
    end

    it 'returns false for non-ignored lines' do
      expect(adapter.skipped?('test.rb', 1)).to be false
      expect(adapter.skipped?('test.rb', 3)).to be false
    end
  end

  describe '#ignored_files' do
    it 'returns ignored files from meta section' do
      adapter = simplecov_coverage_fixture('spec/fixtures/simplecov_with_ignored_files.json')
      expected_ignored = [
        {'string' => 'app/lib/temp/'},
        {'regex' => '/migrate/'},
        {'file' => 'test/factories/user_factory.rb'},
      ]

      expect(adapter.ignored_files).to eq(expected_ignored)
    end

    it 'returns empty array when no ignored files in meta' do
      adapter = simplecov_coverage_fixture('spec/fixtures/nocov.json')
      expect(adapter.ignored_files).to eq([])
    end

    it 'returns empty array when meta section is missing' do
      result = {
        'coverage' => {
          'test.rb' => {'lines' => [1, 0]}
        }
      }
      adapter = described_class.new(result, nil)
      expect(adapter.ignored_files).to eq([])
    end
  end
end
