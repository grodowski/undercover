# frozen_string_literal: true

require 'spec_helper'
require 'undercover'

describe Undercover::Formatter do
  context 'without warnings' do
    let(:results) { {} }

    it 'returns a message' do
      formatted = described_class.new(results).to_s
      expect(formatted).to include('No coverage is missing in latest changes')
    end
  end

  let(:lcov) do
    Undercover::LcovParser.parse('spec/fixtures/fixtures.lcov')
  end
  let(:results) { [result] }

  context 'with warnings from module.rb' do
    let(:ast) { Imagen.from_local('spec/fixtures/module.rb') }
    let(:coverage) { lcov.source_files['module.rb'] }
    let(:node) { ast.find_all(with_name('BaconModule')).first }
    let(:result) { Undercover::Result.new(node, coverage, 'module.rb') }

    it 'returns a useful message with branch coverage for module.rb' do
      formatted = described_class.new(results).to_s
      expect(formatted).to include('some methods have no test coverage')
      expect(formatted).to include('node `BaconModule`')
      expect(formatted).to include('type: module')
      expect(formatted).to include('loc: module.rb:3:23')
      expect(formatted).to include('coverage: 80.0%')
      expect(formatted).to match(/branches:.*1\/2.*$/)
      expect(formatted).to match(/branches:.*2\/2.*$/)
    end
  end

  context 'with warnings from class.rb' do
    let(:ast) { Imagen.from_local('spec/fixtures/class.rb') }
    let(:coverage) { lcov.source_files['class.rb'] }
    let(:node) { ast.find_all(with_name('BaconClass')).first }
    let(:result) { Undercover::Result.new(node, coverage, 'class.rb') }

    it 'returns a useful message with branch coverage for class.rb' do
      formatted = described_class.new(results).to_s
      expect(formatted).to include('some methods have no test coverage')
      expect(formatted).to include('node `BaconClass`')
      expect(formatted).to include('type: class')
      expect(formatted).to include('loc: class.rb:3:18')
      expect(formatted).to include('coverage: 83.33%')
    end
  end
end
