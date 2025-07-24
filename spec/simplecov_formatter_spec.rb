# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe 'SimpleCov::Formatter::Undercover' do
  let(:lines12) { Array.new(12) { [0, 1, nil].sample } }
  let(:lines7) { Array.new(7) { [0, 1, nil].sample } }
  let(:result) do
    SimpleCov::Result.from_hash(
      'rspec' => {
        'coverage' => {
          'spec/fixtures/file_one' => {'lines' => lines7},
          'spec/fixtures/file_two' => {'lines' => lines12}
        },
        'timestamp' => Time.now.to_i
      }
    ).first
  end
  let(:formatter) { SimpleCov::Formatter::Undercover.new }
  let(:formatted_result) { formatter.format_result(result) }

  before do
    allow_any_instance_of(SimpleCov::Result).to receive(:filter!).and_return(nil)
  end

  it 'includes SimpleCov.root in meta' do
    expect(formatted_result[:meta][:simplecov_root]).to eq(SimpleCov.root)
  end

  it 'uses relative paths as keys' do
    expect(formatted_result[:coverage].keys).to match_array(
      ['spec/fixtures/file_one', 'spec/fixtures/file_two']
    )
  end

  it 'formats coverage data correctly' do
    expect(formatted_result[:coverage]['spec/fixtures/file_one']).to eq(branches: [], lines: lines7)
    expect(formatted_result[:coverage]['spec/fixtures/file_two']).to eq(branches: [], lines: lines12)
  end

  it 'executes formatter in practice' do
    result = SimpleCov::Result.from_hash(
      'rspec' => {
        'coverage' => {
          'test.rb' => {'lines' => [1, 0]}
        },
        'timestamp' => Time.now.to_i
      }
    ).first

    allow_any_instance_of(SimpleCov::Result).to receive(:filter!).and_return(nil)

    formatted = SimpleCov::Formatter::Undercover.new.format_result(result)
    expect(formatted).to be_a(Hash)
    expect(formatted).to have_key(:meta)
    expect(formatted).to have_key(:coverage)
  end
end

RSpec.describe 'Undercover::ResultHashFormatterWithRoot' do
  let(:lines) { [1, 0, nil, 1] }
  let(:source_file) do
    double('source_file', project_filename: '/absolute/path/file.rb', filename: '/absolute/path/file.rb')
  end
  let(:result) do
    result = SimpleCov::Result.from_hash(
      'rspec' => {
        'coverage' => {
          '/absolute/path/file.rb' => {'lines' => lines}
        },
        'timestamp' => Time.now.to_i
      }
    ).first
    allow(result).to receive(:files).and_return([source_file])
    result
  end
  let(:formatter) { Undercover::ResultHashFormatterWithRoot.new(result) }

  before do
    allow_any_instance_of(SimpleCov::Result).to receive(:filter!).and_return(nil)
    allow(formatter).to receive(:format_source_file).and_return({lines: lines, branches: []})
  end

  describe '#format' do
    it 'includes timestamp in meta' do
      formatted = formatter.format
      expect(formatted[:meta][:timestamp]).to be_a(Integer)
    end

    it 'includes SimpleCov.root in meta' do
      formatted = formatter.format
      expect(formatted[:meta][:simplecov_root]).to eq(SimpleCov.root)
    end

    it 'formats files with relative paths' do
      formatted = formatter.format
      expect(formatted[:coverage]).to have_key('absolute/path/file.rb')
      expect(formatted[:coverage]).not_to have_key('/absolute/path/file.rb')
    end

    it 'includes ignored files in meta' do
      # Mock the filter definitions to return a mix of filter types
      allow(SimpleCov).to receive(:filter_definitions).and_return([
                                                                    {string: 'spec/'},
                                                                    {regex: '\/test\/'},
                                                                    {file: 'path/custom_ignored.rb'},
                                                                  ])

      formatted = formatter.format

      expect(formatted[:meta][:ignored_files]).to eq([
                                                       {string: 'spec/'},
                                                       {regex: '\/test\/'},
                                                       {file: 'path/custom_ignored.rb'},
                                                     ])
    end

    it 'handles case with no ignored files' do
      # Mock empty filter definitions
      allow(SimpleCov).to receive(:filter_definitions).and_return([])

      formatted = formatter.format

      expect(formatted[:meta][:ignored_files]).to eq([])
    end

    it 'handles mixed filter types' do
      # Mock filter definitions with various types
      allow(SimpleCov).to receive(:filter_definitions).and_return([
                                                                    {string: 'app/models/'},
                                                                    {regex: '\/fixtures\/'},
                                                                    {file: 'specific_ignored.rb'},
                                                                    {string: 'vendor/'},
                                                                  ])

      formatted = formatter.format

      expect(formatted[:meta][:ignored_files]).to eq([
                                                       {string: 'app/models/'},
                                                       {regex: '\/fixtures\/'},
                                                       {file: 'specific_ignored.rb'},
                                                       {string: 'vendor/'},
                                                     ])
    end

    it 'does not add file entries for paths covered by serializable filters' do
      SimpleCov.filter_definitions = nil
      string_filter = SimpleCov::StringFilter.new('spec/')
      allow(SimpleCov).to receive(:filters).and_return([string_filter])

      filtered_file = double('filtered_file', filename: '/absolute/spec/example_spec.rb')
      kept_file = double('kept_file', filename: '/absolute/app/model.rb')

      allow(SimpleCov).to receive(:filtered_uncached).and_return([kept_file])
      allow(SimpleCov).to receive(:root).and_return('/absolute')

      SimpleCov.filtered([kept_file, filtered_file])
      formatted = formatter.format

      expect(formatted[:meta][:ignored_files]).to eq([{string: 'spec/'}])
    end

    it 'adds file entries for paths not covered by serializable filters' do
      SimpleCov.filter_definitions = nil
      string_filter = SimpleCov::StringFilter.new('vendor/')
      allow(SimpleCov).to receive(:filters).and_return([string_filter])

      filtered_file = double('filtered_file', filename: '/absolute/custom/special.rb')
      kept_file = double('kept_file', filename: '/absolute/app/model.rb')

      allow(SimpleCov).to receive(:filtered_uncached).and_return([kept_file])
      allow(SimpleCov).to receive(:root).and_return('/absolute')

      SimpleCov.filtered([kept_file, filtered_file])
      formatted = formatter.format

      expect(formatted[:meta][:ignored_files]).to eq([
                                                       {string: 'vendor/'},
                                                       {file: 'custom/special.rb'},
                                                     ])
    end

    it 'handles regex filters that do not match in covered_by_serializable_filters' do
      SimpleCov.filter_definitions = nil
      regex_filter = SimpleCov::RegexFilter.new(/\/nonexistent\//)
      allow(SimpleCov).to receive(:filters).and_return([regex_filter])

      filtered_file = double('filtered_file', filename: '/absolute/app/model.rb')
      kept_file = double('kept_file', filename: '/absolute/app/other.rb')

      allow(SimpleCov).to receive(:filtered_uncached).and_return([kept_file])
      allow(SimpleCov).to receive(:root).and_return('/absolute')

      SimpleCov.filtered([kept_file, filtered_file])
      formatted = formatter.format

      expect(formatted[:meta][:ignored_files]).to eq([
                                                       {regex: '/nonexistent/'},
                                                       {file: 'app/model.rb'},
                                                     ])
    end

    it 'handles unknown filter types in extract_filter_definitions' do
      SimpleCov.filter_definitions = nil

      custom_filter_class = Class.new(SimpleCov::Filter) do
        def matches?(_source_file)
          true
        end
      end

      string_filter = SimpleCov::StringFilter.new('spec/')
      custom_filter = custom_filter_class.new('custom_argument')
      allow(SimpleCov).to receive(:filters).and_return([string_filter, custom_filter])

      filtered_file = double('filtered_file', filename: '/absolute/custom/file.rb')
      kept_file = double('kept_file', filename: '/absolute/app/model.rb')

      allow(SimpleCov).to receive(:filtered_uncached).and_return([kept_file])
      allow(SimpleCov).to receive(:root).and_return('/absolute')

      SimpleCov.filtered([kept_file, filtered_file])
      formatted = formatter.format

      expect(formatted[:meta][:ignored_files]).to eq([
                                                       {string: 'spec/'},
                                                       {file: 'custom/file.rb'},
                                                     ])
    end
  end

  describe '#add_undercover_meta_fields' do
    it 'adds simplecov_root to meta' do
      formatter.instance_variable_set(:@formatted_result, {meta: {}})
      result = formatter.send(:add_undercover_meta_fields)
      expect(result[:meta][:simplecov_root]).to eq(SimpleCov.root)
    end
  end

  describe '#format_files' do
    it 'uses relative paths as keys' do
      formatter.instance_variable_set(:@formatted_result, {coverage: {}})
      formatter.send(:format_files)
      coverage = formatter.instance_variable_get(:@formatted_result)[:coverage]
      expect(coverage).to have_key('absolute/path/file.rb')
    end
  end
end

RSpec.describe 'Undercover::UndercoverSimplecovFormatter' do
  let(:result) do
    SimpleCov::Result.from_hash(
      'rspec' => {
        'coverage' => {
          'file.rb' => {'lines' => [1, 0]}
        },
        'timestamp' => Time.now.to_i
      }
    ).first
  end
  let(:formatter) { Undercover::UndercoverSimplecovFormatter.new }

  before do
    allow_any_instance_of(SimpleCov::Result).to receive(:filter!).and_return(nil)
  end

  describe '#format_result' do
    it 'returns formatted result using ResultHashFormatterWithRoot' do
      formatted = formatter.format_result(result)
      expect(formatted).to be_a(Hash)
      expect(formatted).to have_key(:meta)
      expect(formatted).to have_key(:coverage)
    end
  end

  describe '.output_filename' do
    it 'allows setting and getting custom output filename' do
      original = Undercover::UndercoverSimplecovFormatter.output_filename

      Undercover::UndercoverSimplecovFormatter.output_filename = 'custom_coverage.json'
      expect(Undercover::UndercoverSimplecovFormatter.output_filename).to eq('custom_coverage.json')

      Undercover::UndercoverSimplecovFormatter.output_filename = original
    end

    it 'defaults to nil when not set' do
      original = Undercover::UndercoverSimplecovFormatter.output_filename
      Undercover::UndercoverSimplecovFormatter.output_filename = nil

      expect(Undercover::UndercoverSimplecovFormatter.output_filename).to be_nil

      Undercover::UndercoverSimplecovFormatter.output_filename = original
    end
  end
end
