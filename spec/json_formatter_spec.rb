# frozen_string_literal: true

require 'spec_helper'
require 'undercover/json_formatter'

describe Undercover::JsonFormatter do
  let(:mock_node) { double('node', name: 'Foo#bar', human_name: 'instance method') }

  let(:mock_result) do
    instance_double(
      Undercover::Result,
      node: mock_node,
      file_path: 'lib/foo.rb',
      first_line: 10,
      last_line: 15,
      coverage_f: 0.5
    ).tap do |result|
      allow(result).to receive(:uncovered?) { |line| [11, 13].include?(line) }
    end
  end

  describe '#to_s' do
    it 'returns valid JSON' do
      formatter = described_class.new([mock_result])
      expect { JSON.parse(formatter.to_s) }.not_to raise_error
    end
  end

  describe '#to_h' do
    context 'with no warnings' do
      subject { described_class.new([]).to_h }

      it 'has empty warnings array' do
        expect(subject[:warnings]).to eq([])
      end

      it 'has zero counts in summary' do
        expect(subject[:summary][:total_warnings]).to eq(0)
        expect(subject[:summary][:files_affected]).to eq(0)
      end
    end

    context 'with warnings' do
      subject { described_class.new([mock_result]).to_h }

      it 'includes warning details' do
        warning = subject[:warnings].first
        expect(warning[:node]).to eq('Foo#bar')
        expect(warning[:type]).to eq('instance method')
        expect(warning[:file]).to eq('lib/foo.rb')
        expect(warning[:first_line]).to eq(10)
        expect(warning[:last_line]).to eq(15)
        expect(warning[:coverage]).to eq(0.5)
        expect(warning[:uncovered_lines]).to eq([11, 13])
      end

      it 'has correct summary counts' do
        expect(subject[:summary][:total_warnings]).to eq(1)
        expect(subject[:summary][:files_affected]).to eq(1)
      end
    end

    context 'with multiple warnings in different files' do
      let(:mock_node2) { double('node', name: 'Bar#baz', human_name: 'instance method') }
      let(:mock_result2) do
        instance_double(
          Undercover::Result,
          node: mock_node2,
          file_path: 'lib/bar.rb',
          first_line: 5,
          last_line: 8,
          coverage_f: 0.0
        ).tap do |result|
          allow(result).to receive(:uncovered?) { |line| [6, 7].include?(line) }
        end
      end

      subject { described_class.new([mock_result, mock_result2]).to_h }

      it 'counts unique files' do
        expect(subject[:summary][:files_affected]).to eq(2)
      end

      it 'counts all warnings' do
        expect(subject[:summary][:total_warnings]).to eq(2)
      end
    end

    context 'with validation error' do
      it 'includes validation key for stale_coverage' do
        output = described_class.new([], :stale_coverage).to_h
        expect(output[:validation]).to eq('stale_coverage')
      end

      it 'excludes validation key for no_changes' do
        output = described_class.new([], :no_changes).to_h
        expect(output).not_to have_key(:validation)
      end

      it 'excludes validation key when no error' do
        output = described_class.new([]).to_h
        expect(output).not_to have_key(:validation)
      end
    end
  end

  describe '#exit_code' do
    it 'returns 0 when validation error present' do
      formatter = described_class.new([mock_result], :stale_coverage)
      expect(formatter.exit_code).to eq(0)
    end

    it 'returns 0 when no warnings' do
      formatter = described_class.new([])
      expect(formatter.exit_code).to eq(0)
    end

    it 'returns 1 when warnings present' do
      formatter = described_class.new([mock_result])
      expect(formatter.exit_code).to eq(1)
    end
  end
end
