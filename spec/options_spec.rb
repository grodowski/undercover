# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

describe Undercover::Options do
  subject(:options) { described_class.new }

  describe '#parse' do
    it 'handles help option' do
      expect { options.parse(['--help']) }
        .to output(/Usage: undercover/).to_stdout
        .and raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
    end

    it 'handles version option' do
      expect { options.parse(['--version']) }
        .to output(/\d+\.\d+\.\d+/).to_stdout
        .and raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
    end

    it 'guesses lcov path' do
      project_name = Pathname.new(File.expand_path('.')).split.last
      default_path = "coverage/lcov/#{project_name}.lcov"
      options.parse([])
      expect(options.lcov).to be_nil

      FileUtils.mkdir_p('coverage/lcov')
      File.write(default_path, nil)
      options.parse([])
      expect(options.lcov).to end_with(default_path)
    ensure
      FileUtils.rm(default_path)
    end

    it 'sets simplecov_resultset from -s option' do
      options.parse(['-s', 'test.json'])
      expect(options.simplecov_resultset).to eq('test.json')
    end

    it 'calls guess_resultset_path when no simplecov_resultset provided' do
      expect(options).to receive(:guess_resultset_path)
      options.parse([])
    end
  end

  describe '#guess_resultset_path' do
    before do
      options.path = '/test/path'
    end

    it 'sets simplecov_resultset when coverage.json exists' do
      expect(File).to receive(:exist?).with('/test/path/coverage/coverage.json').and_return(true)
      options.send(:guess_resultset_path)
      expect(options.simplecov_resultset).to eq('/test/path/coverage/coverage.json')
    end

    it 'does not set simplecov_resultset when coverage.json does not exist' do
      expect(File).to receive(:exist?).with('/test/path/coverage/coverage.json').and_return(false)
      options.send(:guess_resultset_path)
      expect(options.simplecov_resultset).to be_nil
    end
  end

  describe '#args_from_options_file' do
    let(:temp_file) { Tempfile.new('undercover_config') }

    after { temp_file.unlink }

    it 'parses simple arguments without quotes' do
      temp_file.write("-l sample.lcov\n-p /path/to/project")
      temp_file.close

      args = options.send(:args_from_options_file, temp_file.path)
      expect(args).to eq(['-l', 'sample.lcov', '-p', '/path/to/project'])
    end

    it 'parses arguments with single quotes' do
      temp_file.write("-f '*.rb,*.rake'\n-x 'spec/*,test/*'")
      temp_file.close

      args = options.send(:args_from_options_file, temp_file.path)
      expect(args).to eq(['-f', '*.rb,*.rake', '-x', 'spec/*,test/*'])
    end

    it 'parses arguments with double quotes' do
      temp_file.write('-f "*.rb,*.rake"')
      temp_file.close

      args = options.send(:args_from_options_file, temp_file.path)
      expect(args).to eq(['-f', '*.rb,*.rake'])
    end

    it 'handles mixed quotes' do
      temp_file.write('-f "*.rb" -x \'spec/*\'')
      temp_file.close

      args = options.send(:args_from_options_file, temp_file.path)
      expect(args).to eq(['-f', '*.rb', '-x', 'spec/*'])
    end

    it 'handles quotes with spaces' do
      temp_file.write('-f "*.rb,lib/**/*.rb" -x "spec with spaces/*"')
      temp_file.close

      args = options.send(:args_from_options_file, temp_file.path)
      expect(args).to eq(['-f', '*.rb,lib/**/*.rb', '-x', 'spec with spaces/*'])
    end

    it 'ignores empty lines and comments' do
      temp_file.write("# This is a comment\n-l sample.lcov\n\n-p /path")
      temp_file.close

      args = options.send(:args_from_options_file, temp_file.path)
      expect(args).to eq(['-l', 'sample.lcov', '-p', '/path'])
    end

    it 'handles multiple arguments on one line' do
      temp_file.write('-l sample.lcov -p /path -f "*.rb"')
      temp_file.close

      args = options.send(:args_from_options_file, temp_file.path)
      expect(args).to eq(['-l', 'sample.lcov', '-p', '/path', '-f', '*.rb'])
    end

    it 'ensures parsed values from quoted glob lists have quotes removed' do
      temp_file.write('-f "*.rb,lib/**/*.rb" -x "spec/*,test/*"')
      temp_file.close

      args = options.send(:args_from_options_file, temp_file.path)
      expect(args).to eq(['-f', '*.rb,lib/**/*.rb', '-x', 'spec/*,test/*'])

      options.parse(args)
      expect(options.glob_allow_filters).to eq(['*.rb', 'lib/**/*.rb'])
      expect(options.glob_reject_filters).to eq(['spec/*', 'test/*'])
    end
  end

  describe 'file filter options with quotes' do
    it 'parses include-files with comma-separated values' do
      options.parse(['-f', '*.rb,lib/**/*.rb'])
      expect(options.glob_allow_filters).to eq(['*.rb', 'lib/**/*.rb'])
    end

    it 'parses exclude-files with comma-separated values' do
      options.parse(['-x', 'spec/*,test/*'])
      expect(options.glob_reject_filters).to eq(['spec/*', 'test/*'])
    end

    it 'handles complex glob patterns' do
      options.parse(['-f', '*.rb,app/**/*.rb,lib/**/*.{rb,rake}'])
      expect(options.glob_allow_filters).to eq(['*.rb', 'app/**/*.rb', 'lib/**/*.{rb,rake}'])
    end

    it 'handles multiple brace patterns' do
      options.parse(['-f', '*.{rb,rake},lib/**/*.{rb,rake,ru}'])
      expect(options.glob_allow_filters).to eq(['*.{rb,rake}', 'lib/**/*.{rb,rake,ru}'])
    end
  end
end
