# frozen_string_literal: true

require 'spec_helper'
require 'undercover'

describe Undercover::Result do
  let(:ast) { all_nodes('spec/fixtures/class.rb') }
  let(:lcov) do
    Undercover::LcovParser.parse('spec/fixtures/fixtures.lcov', nil)
  end
  let(:coverage) { lcov }

  it 'computes class coverage as float' do
    node = ast.find(&with_name('BaconClass'))
    result = described_class.new(node, coverage, 'class.rb')

    expect(result.coverage_f).to eq(0.8333)
  end

  it 'computes method coverage as float' do
    node = ast.find(&with_name('bar'))
    result = described_class.new(node, coverage, 'class.rb')

    expect(result.coverage_f).to eq(1.0)
  end

  it 'computes coverage for a not covered method' do
    node = ast.find(&with_name('foo'))
    result = described_class.new(node, coverage, 'class.rb')

    expect(result.coverage_f).to eq(0.0)
  end

  it 'reads coverage from a shared index instead of the adapter' do
    node = ast.find(&with_name('BaconClass'))
    expected = described_class.new(node, coverage, 'class.rb').coverage
    index = Undercover::CoverageIndex.new(coverage.coverage('class.rb'))

    expect(coverage).not_to receive(:coverage)
    expect(described_class.new(node, coverage, 'class.rb', coverage_index: index).coverage).to eq(expected)
  end

  it 'has a fiendly #inspect' do
    node = ast.find(&with_name('foo'))
    result = described_class.new(node, coverage, 'class.rb')

    expect(result.to_s).to match(/#<Undercover::Report::Result:\d+ name: foo, coverage: 0.0/)
  end

  context 'for an empty module def' do
    let(:ast) { all_nodes('spec/fixtures/empty_class_def.rb') }
    let(:lcov) do
      Undercover::LcovParser.parse('spec/fixtures/empty_class_def.lcov')
    end
    let(:coverage) { lcov }

    it 'is not NaN' do
      node = ast.find(&with_name('ApplicationJob'))
      result = described_class.new(node, coverage, 'empty_class_def.rb')

      expect(result.coverage_f).to eq(1.0)
    end
  end

  context 'for a branch without line coverage' do
    let(:ast) { all_nodes('spec/fixtures/module.rb') }
    let(:lcov) do
      Undercover::LcovParser.parse('spec/fixtures/fixtures.lcov')
    end
    let(:coverage) { lcov }

    it 'uncovered gives false' do
      node = ast.find(&with_name('foobar'))
      result = described_class.new(node, coverage, 'module.rb')

      expect(result.uncovered?(27)).to be_falsy
    end
  end

  context 'for oneline block uncovered' do
    let(:ast) { all_nodes('spec/fixtures/one_line_block.rb') }
    let(:lcov) do
      Undercover::LcovParser.parse('spec/fixtures/one_line_block.lcov')
    end
    let(:coverage) { lcov }

    it 'uncovered gives true' do
      node = ast.last
      result = described_class.new(node, coverage, 'one_line_block.rb')

      expect(result.uncovered?(7)).to be_truthy
    end
  end

  context 'for single-line node covered' do
    let(:ast) { all_nodes('spec/fixtures/single_line.rb') }
    let(:lcov) do
      Undercover::LcovParser.parse('spec/fixtures/single_line.lcov')
    end
    let(:coverage) { lcov }

    it 'uncovered gives false' do
      node = ast.last
      result = described_class.new(node, coverage, 'single_line.rb')

      expect(result.uncovered?(1)).to be_falsy
    end
  end

  context 'for method call with block across multiple lines' do
    let(:source_file) do
      "[1]\n." \
        'map { |x| x + 1 }'
    end
    let(:ast) do
      all_nodes('method_block_multi.rb', source_file)
    end
    let(:lcov) do
      file = Tempfile.new
      file.write <<~LCOV
        SF:./method_block_multi.rb
        DA:1,1
        DA:2,1
        end_of_record
      LCOV
      file.flush
      Undercover::LcovParser.parse(file).tap { file.close }
    end
    let(:coverage) { lcov }

    it "doesn't report false positive on block" do
      node = ast.last
      result = described_class.new(node, coverage, 'method_block_multi.rb')

      expect(result.uncovered?(1)).to be_falsy
    end
  end

  context 'for method call with a do end block across multiple lines' do
    let(:source_file) do
      "[1]\n." \
        "map do |x|\n" \
        "x + 1\n" \
        "end\n"
    end
    let(:ast) do
      all_nodes('method_block_multi.rb', source_file)
    end
    let(:lcov) do
      file = Tempfile.new
      file.write <<~LCOV
        SF:./method_block_multi.rb
        DA:1,1
        DA:2,1
        DA:3,1
        DA:4,1
        end_of_record
      LCOV
      file.flush
      Undercover::LcovParser.parse(file).tap { file.close }
    end
    let(:coverage) { lcov }

    it "doesn't report false positive on block" do
      node = ast.last
      result = described_class.new(node, coverage, 'method_block_multi.rb')

      expect(result.uncovered?(1)).to be_falsy
    end
  end

  context 'for single line def and defs' do
    let(:source_file) do
      "def single; puts 'foo'; end\n" \
        "def c_single; puts 'bar'; end\n"
    end
    let(:ast) do
      all_nodes('def_single_line.rb', source_file)
    end
    let(:lcov) do
      file = Tempfile.new
      file.write <<~LCOV
        SF:./def_single_line.rb
        DA:1,1
        DA:2,1
        end_of_record
      LCOV
      file.flush
      Undercover::LcovParser.parse(file).tap { file.close }
    end
    let(:coverage) { lcov }

    it "doesn't report false positive on block" do
      nodes = ast
      nodes.each do |node|
        result = described_class.new(node, coverage, 'def_single_line.rb')
        expect(result.uncovered?(1)).to be_falsy
        expect(result.coverage_f).to eq(1.0)
      end
    end
  end

  context ':nocov: with a SimpleCov report' do
    let(:ast) { all_nodes('spec/fixtures/nocov.rb') }
    let(:simplecov) do
      # effect of nocov_token - files ignored entirely or partially in the coverage file
      simplecov_coverage_fixture 'spec/fixtures/nocov.json'
    end
    let(:coverage) { simplecov }

    it 'respects lines skipped by simplecov' do
      nodes = ast

      skipped_result = described_class.new(nodes[0], coverage, 'spec/fixtures/nocov.rb')
      flagged_result = described_class.new(nodes[1], coverage, 'spec/fixtures/nocov.rb')

      1.upto(8).each do |line_no|
        expect(skipped_result.uncovered?(line_no)).to be_falsy
        expect(coverage.skipped?('spec/fixtures/nocov.rb', line_no)).to be_truthy
      end
      expect(flagged_result.uncovered?(12)).to be_falsy
      expect(flagged_result.uncovered?(13)).to be_truthy
      expect(flagged_result.uncovered?(14)).to be_truthy

      expect(flagged_result.coverage_f).to eq(0.6667)
    end
  end

  context ':nocov: with SimpleCov report and multi-line branch coverage' do
    let(:ast) { all_nodes('spec/fixtures/branch_ignored.rb') }
    let(:simplecov) do
      simplecov_coverage_fixture 'spec/fixtures/branch_ignored_coverage/branch_ignored_test.json'
    end
    let(:coverage) { simplecov }

    it 'accepts ignored branches with present line coverage (:nocov: edge case)' do
      nodes = ast
      test_method_result = described_class.new(nodes[0], coverage, 'branch_ignored.rb')

      # has ignored branch due to overlap with :nocov:, but uningnored lines
      1.upto(4).each do |line_no|
        expect(test_method_result.uncovered?(2)).to be_falsy
        expect(coverage.skipped?('branch_ignored.rb', line_no)).to be_falsy
      end

      6.upto(8).each do |line_no|
        expect(test_method_result.uncovered?(line_no)).to be_falsy
        expect(coverage.skipped?('branch_ignored.rb', line_no)).to be_truthy
      end

      expect(test_method_result.coverage_f).to eq(1.0)
    end

    it '#pretty_print prints skipped branch' do
      nodes = ast
      test_method_result = described_class.new(nodes[0], coverage, 'branch_ignored.rb')

      pretty_output = test_method_result.pretty_print
      stripped_output = pretty_output.gsub(/\e\[[0-9;]*m/, '') # remove colors for testing

      expected_output = <<~OUTPUT
         1: def test_branch_ignored(arg) hits: n/a
         2:   if arg == :arg1 hits: 1 branches: 1/1
         3:     if ENV["FOO"] != "BAR" hits: 1 branches: 1/1
         4:       :sym1 hits: 1 branches: 1/1
         5:     # :nocov: skipped
         6:     else skipped
         7:       :sym2 skipped
         8:     end skipped
         9:     # :nocov: skipped
        10:   end hits: n/a
        11: end hits: n/a
      OUTPUT
      expect(stripped_output.strip).to eq(expected_output.strip)
    end
  end

  context 'with skipped lines in coverage' do
    let(:file_path) { 'test.rb' }
    let(:source_file) do
      "def foo\n  " \
        "puts 'bar'\n" \
        "end\n"
    end
    let(:ast) do
      all_nodes(file_path, source_file)
    end
    let(:mock_coverage) do
      coverage_data = [
        [1, 1], [2, 0], [3, 1]
      ]
      double('coverage', coverage: coverage_data, skipped?: true, method_coverage: nil)
    end

    it 'handles skipped lines correctly' do
      node = ast.find { |n| n.name == 'foo' }
      result = described_class.new(node, mock_coverage, file_path)

      # This should trigger the skipped line handling in the coverage block
      expect(result.coverage_f).to be > 0
    end
  end

  context 'with actually skipped lines that trigger the early return' do
    let(:file_path) { 'skipped_test.rb' }
    let(:source_file) do
      "def skipped_method\n  " \
        "puts 'this is skipped'\n" \
        "end\n"
    end
    let(:ast) do
      all_nodes(file_path, source_file)
    end
    let(:mock_coverage_with_skipped) do
      coverage_data = [
        [2, 0], [3, 1] # Only lines that are inside the method body
      ]
      coverage_mock = double('coverage')
      allow(coverage_mock).to receive(:coverage).with(file_path).and_return(coverage_data)
      allow(coverage_mock).to receive(:skipped?).with(file_path, 2).and_return(true)
      allow(coverage_mock).to receive(:skipped?).with(file_path, 3).and_return(false)
      allow(coverage_mock).to receive(:method_coverage).and_return(nil)
      coverage_mock
    end

    it 'marks skipped lines as covered and skips to next iteration' do
      node = ast.find { |n| n.name == 'skipped_method' }
      result = described_class.new(node, mock_coverage_with_skipped, file_path)

      # Line 2 should be marked as covered (1) due to being skipped
      # Line 3 should be marked as covered (1) normally
      # This should result in 2/2 = 1.0 coverage
      expect(result.coverage_f).to eq(1.0)
    end
  end

  context 'with pretty print formatting' do
    let(:ast) { all_nodes('spec/fixtures/class.rb') }
    let(:coverage) { lcov }

    it 'handles different line types in pretty_print' do
      node = ast.find(&with_name('BaconClass'))
      result = described_class.new(node, coverage, 'class.rb')

      # Test the pretty_print method that has uncovered branches
      pretty_output = result.pretty_print
      expect(pretty_output).to be_a(String)
      expect(pretty_output).to include('BaconClass')
    end

    it 'handles skipped lines in pretty_print output' do
      # Create a result with a line that will be skipped
      file_path = 'skipped_test.rb'
      source_file = "def test_method\n  puts 'skipped line'\n  puts 'normal line'\nend\n"

      ast = all_nodes(file_path, source_file)
      node = ast.find { |n| n.name == 'test_method' }

      # Create mock coverage that will return true for skipped? on line 2
      mock_coverage = double('coverage')
      coverage_data = [[2, 0], [3, 1]] # Lines within the method
      allow(mock_coverage).to receive(:coverage).with(file_path).and_return(coverage_data)
      allow(mock_coverage).to receive(:skipped?).and_return(false) # Default to false
      allow(mock_coverage).to receive(:skipped?).with(file_path, 2).and_return(true)
      allow(mock_coverage).to receive(:method_coverage).and_return(nil)

      result = described_class.new(node, mock_coverage, file_path)

      # This should trigger the skipped line formatting (lines 106-108)
      pretty_output = result.pretty_print
      expect(pretty_output).to include('skipped')
    end
  end

  describe '#branches' do
    let(:source_file) { "def foo\n  a\n  x ? a : b\n  b\nend\n" }
    let(:file_path) { 'test.rb' }
    let(:ast) do
      all_nodes(file_path, source_file)
    end
    let(:mock_adapter) do
      double('adapter').tap do |a|
        coverage_data = [
          [3, 0, 1, 0],
          [3, 0, 2, 3],
          [3, 0, 3, 'ignored'],
          [4, 0, 4, 0],
        ]
        allow(a).to receive(:coverage).with(file_path).and_return(coverage_data)
        allow(a).to receive(:skipped?).and_return(false)
      end
    end

    subject do
      node = ast.find(&with_name('foo'))
      described_class.new(node, mock_adapter, file_path).branches
    end

    it 'returns all branch entries including covered and ignored' do
      expect(subject.size).to eq(4)
    end

    it 'returns structured hashes with line, block, branch and count' do
      expect(subject).to eq([
                              {line: 3, block: 0, branch: 1, count: 0},
                              {line: 3, block: 0, branch: 2, count: 3},
                              {line: 3, block: 0, branch: 3, count: 'ignored'},
                              {line: 4, block: 0, branch: 4, count: 0},
                            ])
    end

    it 'does not include description keys' do
      expect(subject.none? { |b| b.key?(:description) }).to be true
    end
  end

  context 'safe navigation in method arg' do
    let(:ast) { all_nodes('spec/fixtures/safe_navigation_in_method_arg.rb') }

    context 'for a json file' do
      let(:simplecov) do
        simplecov_coverage_fixture 'spec/fixtures/safe_navigation_in_method_arg.json'
      end

      let(:coverage) { simplecov }

      it '#pretty_print prints branch on n/a line' do
        nodes = ast
        test_method_result = described_class.new(nodes[1], coverage, 'safe_navigation_in_method_arg.rb')

        pretty_output = test_method_result.pretty_print
        stripped_output = pretty_output.gsub(/\e\[[0-9;]*m/, '') # remove colors for testing

        expected_output = <<~OUTPUT
           5: def process_input(input, something: nil) hits: n/a
           6:   return unless input.nil? hits: 2 branches: 2/2
           7:#{' '}
           8:   log_exception( hits: 1
           9:     999, hits: n/a
          10:     something&.id hits: n/a branches: 1/2
          11:   ) hits: n/a
          12: end hits: n/a
        OUTPUT
        expect(stripped_output.strip).to eq(expected_output.strip)
      end
    end

    context 'for an lcov file' do
      let(:lcov) do
        Undercover::LcovParser.parse('spec/fixtures/safe_navigation_in_method_arg.lcov')
      end

      it '#pretty_print prints branch on n/a line' do
        nodes = ast
        test_method_result = described_class.new(nodes[1], coverage, 'safe_navigation_in_method_arg.rb')

        pretty_output = test_method_result.pretty_print
        stripped_output = pretty_output.gsub(/\e\[[0-9;]*m/, '') # remove colors for testing

        expected_output = <<~OUTPUT
           5: def process_input(input, something: nil) hits: n/a
           6:   return unless input.nil? hits: 2 branches: 2/2
           7:#{' '}
           8:   log_exception( hits: 1
           9:     999, hits: n/a
          10:     something&.id hits: n/a branches: 1/2
          11:   ) hits: n/a
          12: end hits: n/a
        OUTPUT
        expect(stripped_output.strip).to eq(expected_output.strip)
      end
    end
  end

  context 'with method coverage' do
    let(:file_path) { 'spec/fixtures/method_coverage.rb' }
    let(:ast) { all_nodes(file_path) }
    let(:coverage) { simplecov_coverage_fixture('spec/fixtures/method_coverage.json') }

    def result_for(name)
      described_class.new(ast.find(&with_name(name)), coverage, file_path)
    end

    context 'for a one-line method never called' do
      subject(:result) { result_for('never_called_one_liner') }

      it 'is uncovered although its line ran when the file loaded' do
        expect(result.method_called?).to be(false)
        expect(result.uncovered?(4)).to be(true)
        expect(result.coverage_f).to eq(0.0)
      end

      it 'says so in #pretty_print' do
        expect(result.pretty_print.gsub(/\e\[[0-9;]*m/, ''))
          .to eq('4:   def never_called_one_liner = :never method never called')
      end
    end

    context 'for a one-line method called' do
      subject(:result) { result_for('called_one_liner') }

      it 'is covered' do
        expect(result.method_called?).to be(true)
        expect(result.uncovered?(2)).to be(false)
        expect(result.coverage_f).to eq(1.0)
      end
    end

    context 'for a multi-line method never called' do
      subject(:result) { result_for('never_called') }

      it 'is uncovered on every line, including its signature lines, which have no line coverage' do
        expect(result.uncovered?(6)).to be(true)
        expect(result.uncovered?(7)).to be(true)
        expect(result.uncovered?(9)).to be(true)
        expect(result.uncovered?(10)).to be(true)
        expect(result.coverage_f).to eq(0.0)
      end
    end

    context 'for a called method with no line events in its body' do
      subject(:result) { result_for('called_with_literal_body') }

      it 'is covered' do
        expect(result.coverage).to be_empty
        expect(result.uncovered?(14)).to be(false)
        expect(result.coverage_f).to eq(1.0)
      end
    end

    context 'for a method ignored by SimpleCov' do
      subject(:result) { result_for('ignored_one_liner') }

      it 'has no method coverage, and its skipped line stays covered' do
        expect(result.method_coverage?).to be(false)
        expect(result.uncovered?(17)).to be(false)
      end
    end

    it 'has no method coverage for other nodes' do
      expect(result_for('MethodCoverage').method_coverage?).to be(false)
    end

    it 'refuses to tell whether a node without method coverage was called' do
      expect { result_for('MethodCoverage').method_called? }
        .to raise_error(described_class::NoMethodCoverageError, "no method coverage for #{file_path}:1:18")
    end

    it 'counts a def defined in several classes as called when any of them was' do
      report = {
        'coverage' => {
          'concern.rb' => {
            'lines' => [1, 1, nil, 1, nil],
            'methods' => [
              {'start_line' => 2, 'end_line' => 2, 'coverage' => 0},
              {'start_line' => 2, 'end_line' => 2, 'coverage' => 4},
              {'start_line' => 4, 'end_line' => 4, 'coverage' => 0},
              {'start_line' => 4, 'end_line' => 4, 'coverage' => 0},
            ]
          }
        }
      }
      adapter = Undercover::SimplecovResultAdapter.new(report)
      nodes = all_nodes('concern.rb', "included do\n  def foo = 1\n\n  def bar = 2\nend\n")

      expect(described_class.new(nodes.find(&with_name('foo')), adapter, 'concern.rb').method_called?).to be(true)
      expect(described_class.new(nodes.find(&with_name('bar')), adapter, 'concern.rb').method_called?).to be(false)
    end

    it 'keeps line coverage alone for an LCOV report' do
      result = described_class.new(all_nodes('spec/fixtures/class.rb').find(&with_name('foo')), lcov, 'class.rb')

      expect(result.method_coverage?).to be(false)
    end
  end
end
