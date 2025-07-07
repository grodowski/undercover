# frozen_string_literal: true

require 'spec_helper'

describe Undercover::Options do
  subject(:options) { described_class.new }

  describe '#parse' do
    it 'handles help option' do
      expect { options.parse(['--help']) }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(0)
      end
    end

    it 'handles version option' do
      expect { options.parse(['--version']) }.to raise_error(SystemExit) do |error|
        expect(error.status).to eq(0)
      end
    end

    it 'sets simplecov_resultset from -s option' do
      options.parse(['-s', 'test.json'])
      expect(options.simplecov_resultset).to eq('test.json')
    end

    it 'calls guess_resultset_path when no simplecov_resultset provided' do
      expect(options).to receive(:guess_resultset_path)
      options.parse([])
    end

    it 'does not call guess_lcov_path when simplecov_resultset is set' do
      options.simplecov_resultset = 'test.json'
      expect(options).not_to receive(:guess_lcov_path)
      options.parse([])
      expect(options.lcov).to be_nil
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
end
