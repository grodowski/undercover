# frozen_string_literal: true

require 'spec_helper'
require 'undercover/json_formatter'

describe Undercover::JsonFormatter do
  let(:mock_node) { double('node', name: 'Foo#bar', human_name: 'instance method', ast_node: nil) }

  let(:mock_coverage) { [[11, 0], [12, 5]] }
  let(:mock_branches) { [] }

  let(:mock_result) do
    instance_double(
      Undercover::Result,
      node: mock_node,
      file_path: 'lib/foo.rb',
      first_line: 10,
      last_line: 15,
      coverage_f: 0.5,
      coverage: mock_coverage
    ).tap do |result|
      allow(result).to receive(:skipped?).and_return(false)
      allow(result).to receive(:branches).and_return(mock_branches)
      allow(result).to receive(:branch_label).and_return(nil)
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
      let(:mock_branches) do
        [
          {line: 13, block: 0, branch: 0, count: 0}, # uncovered
          {line: 13, block: 0, branch: 1, count: 3}, # covered
        ]
      end

      subject { described_class.new([mock_result]).to_h }

      it 'includes warning details' do
        warning = subject[:warnings].first
        expect(warning[:node]).to eq('Foo#bar')
        expect(warning[:type]).to eq('instance method')
        expect(warning[:file]).to eq('lib/foo.rb')
        expect(warning[:first_line]).to eq(10)
        expect(warning[:last_line]).to eq(15)
        expect(warning[:coverage]).to eq(0.5)
      end

      it 'reports uncovered lines separately from branches' do
        warning = subject[:warnings].first
        expect(warning[:uncovered_lines]).to eq([11])
      end

      it 'reports uncovered branches with line, block and branch identifiers' do
        warning = subject[:warnings].first
        expect(warning[:uncovered_branches]).to eq([{line: 13, block: 0, branch: 0}])
      end

      it 'does not include covered branches in uncovered_branches' do
        warning = subject[:warnings].first
        expect(warning[:uncovered_branches].none? { |b| b[:branch] == 1 }).to be true
      end

      it 'has correct summary counts' do
        expect(subject[:summary][:total_warnings]).to eq(1)
        expect(subject[:summary][:files_affected]).to eq(1)
      end
    end

    context 'when branches are marked as ignored' do
      let(:mock_branches) do
        [
          {line: 11, block: 0, branch: 0, count: 'ignored'},
          {line: 11, block: 0, branch: 1, count: 0},
        ]
      end

      subject { described_class.new([mock_result]).to_h }

      it 'excludes ignored branches from uncovered_branches' do
        warning = subject[:warnings].first
        expect(warning[:uncovered_branches]).to eq([{line: 11, block: 0, branch: 1}])
      end
    end

    context 'when two branches share the same line (e.g. ternary)' do
      let(:mock_branches) do
        [
          {line: 13, block: 0, branch: 1, count: 0},
          {line: 13, block: 0, branch: 2, count: 0},
        ]
      end

      before do
        allow(mock_result).to receive(:branch_label).with('lib/foo.rb', 1).and_return('then')
        allow(mock_result).to receive(:branch_label).with('lib/foo.rb', 2).and_return('else')
      end

      subject { described_class.new([mock_result]).to_h }

      it 'includes description from branch_label for multi-branch lines' do
        branches = subject[:warnings].first[:uncovered_branches]
        expect(branches.map { |b| b[:description] }).to eq(%w[then else])
      end
    end

    context 'with a single branch on a line' do
      let(:mock_branches) { [{line: 10, block: 0, branch: 0, count: 0}] }

      subject { described_class.new([mock_result]).to_h }

      it 'does not include a description when branch has no annotation' do
        entry = subject[:warnings].first[:uncovered_branches].first
        expect(entry).to eq({line: 10, block: 0, branch: 0})
        expect(entry).not_to have_key(:description)
      end
    end

    context 'with multiple warnings in different files' do
      let(:mock_node2) { double('node', name: 'Bar#baz', human_name: 'instance method', ast_node: nil) }
      let(:mock_result2) do
        instance_double(
          Undercover::Result,
          node: mock_node2,
          file_path: 'lib/bar.rb',
          first_line: 5,
          last_line: 8,
          coverage_f: 0.0,
          coverage: [[6, 0], [7, 0]]
        ).tap do |result|
          allow(result).to receive(:skipped?).and_return(false)
          allow(result).to receive(:branches).and_return([])
          allow(result).to receive(:branch_label).and_return(nil)
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
