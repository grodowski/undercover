# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Direct method execution for coverage tracking' do
  describe 'Undercover::ResultHashFormatterWithRoot' do
    it 'directly executes format method and all its internal calls' do
      # Create a real SimpleCov result
      temp_file = Tempfile.new(['test', '.rb'])
      temp_file.write("puts 'test'\n")
      temp_file.close

      result = SimpleCov::Result.from_hash({
                                             'test' => {
                                               'coverage' => {
                                                 temp_file.path => {'lines' => [1]}
                                               },
                                               'timestamp' => Time.now.to_i
                                             }
                                           }).first

      # Directly instantiate and call the formatter
      formatter = Undercover::ResultHashFormatterWithRoot.new(result)

      # This should execute lines 7-12 (format method)
      output = formatter.format

      expect(output[:meta][:timestamp]).to be_a(Integer)
      expect(output[:meta][:simplecov_root]).to eq(SimpleCov.root)
      expect(output[:coverage]).to be_a(Hash)

      temp_file.unlink
    end

    it 'directly calls private methods' do
      result = double('result', created_at: Time.now, files: [])
      formatter = Undercover::ResultHashFormatterWithRoot.new(result)

      # Set up the instance variable to test private methods
      formatter.instance_variable_set(:@formatted_result, {meta: {timestamp: 123}})

      # This should execute lines 16-20 (add_undercover_meta_fields)
      result = formatter.send(:add_undercover_meta_fields)
      expect(result[:meta][:simplecov_root]).to eq(SimpleCov.root)

      # Reset and test format_files
      source_file = double('source_file', project_filename: '/absolute/path/test.rb')
      formatter.instance_variable_set(:@formatted_result, {coverage: {}})
      allow(formatter).to receive(:format_source_file).and_return({lines: [1], branches: []})
      allow(formatter.instance_variable_get(:@result)).to receive(:files).and_return([source_file])

      # This should execute lines 23-29 (format_files and the block)
      formatter.send(:format_files)
      coverage = formatter.instance_variable_get(:@formatted_result)[:coverage]
      expect(coverage['absolute/path/test.rb']).to eq({lines: [1], branches: []})
    end
  end

  describe 'Undercover::UndercoverSimplecovFormatter' do
    it 'directly executes format_result method' do
      result = double('result', created_at: Time.now, files: [])
      formatter = Undercover::UndercoverSimplecovFormatter.new

      # Mock the ResultHashFormatterWithRoot to avoid infinite recursion
      root_formatter = double('root_formatter')
      expect(Undercover::ResultHashFormatterWithRoot).to receive(:new).with(result).and_return(root_formatter)
      expect(root_formatter).to receive(:format).and_return({meta: {}, coverage: {}})

      # This should execute lines 33-36 (format_result method)
      output = formatter.format_result(result)
      expect(output).to eq({meta: {}, coverage: {}})
    end
  end

  describe 'Undercover::SimplecovResultAdapter.parse' do
    it 'directly executes the parse class method' do
      json_content = {
        'coverage' => {
          'test_file.rb' => {'lines' => [1, 0, 1], 'branches' => []}
        }
      }.to_json

      file = StringIO.new(json_content)

      # This should execute lines 13-20 (parse method including JSON.parse and error handling)
      adapter = Undercover::SimplecovResultAdapter.parse(file)

      expect(adapter).to be_a(Undercover::SimplecovResultAdapter)
      expect(adapter.simplecov_result['coverage']).to have_key('test_file.rb')

      # Test with options
      file2 = StringIO.new(json_content)
      opts = double('options', path: '/test/path')
      adapter2 = Undercover::SimplecovResultAdapter.parse(file2, opts)
      expect(adapter2.instance_variable_get(:@code_dir)).to eq('/test/path')

      # Test empty JSON error path
      empty_file = StringIO.new('{}')
      expect { Undercover::SimplecovResultAdapter.parse(empty_file) }
        .to raise_error(ArgumentError, 'empty SimpleCov')
    end
  end
end
