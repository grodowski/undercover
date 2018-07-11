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

  context 'with warnings' do
    let(:ast) { Imagen.from_local('spec/fixtures/class.rb') }
    let(:lcov) do
      Undercover::LcovParser.parse('spec/fixtures/fixtures.lcov')
    end
    let(:coverage) { lcov.source_files['class.rb'] }
    let(:node) { ast.find_all(with_name('BaconClass')).first }
    let(:result) { Undercover::Result.new(node, coverage, 'class.rb') }

    let(:results) { [result] }

    it 'returns a useful message' do
      formatted = described_class.new(results).to_s
      expect(formatted).to include('some methods have no test coverage')
      expect(formatted).to include('node `BaconClass`')
      expect(formatted).to include('type: class')
      expect(formatted).to include('loc: class.rb:3:18')
      expect(formatted).to include('coverage: 83.33%')
    end
  end
end
