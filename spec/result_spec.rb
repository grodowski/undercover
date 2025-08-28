# frozen_string_literal: true

require 'spec_helper'
require 'undercover'

describe Undercover::Result do
  let(:ast) { Imagen.from_local('spec/fixtures/class.rb') }
  let(:lcov) do
    Undercover::LcovParser.parse('spec/fixtures/fixtures.lcov', nil)
  end
  let(:coverage) { lcov }

  it 'computes class coverage as float' do
    node = ast.find_all(with_name('BaconClass')).first
    result = described_class.new(node, coverage, 'class.rb')

    expect(result.coverage_f).to eq(0.8333)
  end

  it 'computes method coverage as float' do
    node = ast.find_all(with_name('bar')).first
    result = described_class.new(node, coverage, 'class.rb')

    expect(result.coverage_f).to eq(1.0)
  end

  it 'computes coverage for a not covered method' do
    node = ast.find_all(with_name('foo')).first
    result = described_class.new(node, coverage, 'class.rb')

    expect(result.coverage_f).to eq(0.0)
  end

  it 'has a fiendly #inspect' do
    node = ast.find_all(with_name('foo')).first
    result = described_class.new(node, coverage, 'class.rb')

    expect(result.to_s).to match(/#<Undercover::Report::Result:\d+ name: foo, coverage: 0.0/)
  end

  context 'for an empty module def' do
    let(:ast) { Imagen.from_local('spec/fixtures/empty_class_def.rb') }
    let(:lcov) do
      Undercover::LcovParser.parse('spec/fixtures/empty_class_def.lcov')
    end
    let(:coverage) { lcov }

    it 'is not NaN' do
      node = ast.find_all(with_name('ApplicationJob')).first
      result = described_class.new(node, coverage, 'empty_class_def.rb')

      expect(result.coverage_f).to eq(1.0)
    end
  end

  context 'for a branch without line coverage' do
    let(:ast) { Imagen.from_local('spec/fixtures/module.rb') }
    let(:lcov) do
      Undercover::LcovParser.parse('spec/fixtures/fixtures.lcov')
    end
    let(:coverage) { lcov }

    it 'uncovered gives false' do
      node = ast.find_all(with_name('foobar')).first
      result = described_class.new(node, coverage, 'module.rb')

      expect(result.uncovered?(27)).to be_falsy
    end
  end

  context 'for oneline block uncovered' do
    let(:ast) { Imagen.from_local('spec/fixtures/one_line_block.rb') }
    let(:lcov) do
      Undercover::LcovParser.parse('spec/fixtures/one_line_block.lcov')
    end
    let(:coverage) { lcov }

    it 'uncovered gives true' do
      node = ast.children[0].find_all(->(_) { true }).last
      result = described_class.new(node, coverage, 'one_line_block.rb')

      expect(result.uncovered?(7)).to be_truthy
    end
  end

  context 'for single-line node covered' do
    let(:ast) { Imagen.from_local('spec/fixtures/single_line.rb') }
    let(:lcov) do
      Undercover::LcovParser.parse('spec/fixtures/single_line.lcov')
    end
    let(:coverage) { lcov }

    it 'uncovered gives false' do
      node = ast.children[0].find_all(->(_) { true }).last
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
      root = Imagen::Node::Root.new
      Imagen::Visitor.traverse(Imagen::AST::Parser.parse(source_file, 'method_block_multi.rb'), root)
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
      node = ast.children[0].find_all(->(_) { true }).last
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
      root = Imagen::Node::Root.new
      Imagen::Visitor.traverse(Imagen::AST::Parser.parse(source_file, 'method_block_multi.rb'), root)
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
      node = ast.children[0].find_all(->(_) { true }).last
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
      root = Imagen::Node::Root.new
      Imagen::Visitor.traverse(Imagen::AST::Parser.parse(source_file, 'def_single_line.rb'), root)
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
      nodes = ast.find_all(->(node) { !node.is_a?(Imagen::Node::Root) })
      nodes.each do |node|
        result = described_class.new(node, coverage, 'def_single_line.rb')
        expect(result.uncovered?(1)).to be_falsy
        expect(result.coverage_f).to eq(1.0)
      end
    end
  end

  context ':nocov: with a SimpleCov report' do
    let(:ast) { Imagen.from_local('spec/fixtures/nocov.rb') }
    let(:simplecov) do
      # effect of nocov_token - files ignored entirely or partially in the coverage file
      simplecov_coverage_fixture 'spec/fixtures/nocov.json'
    end
    let(:coverage) { simplecov }

    it 'respects lines skipped by simplecov' do
      nodes = ast.find_all(->(node) { !node.is_a?(Imagen::Node::Root) })

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
    let(:ast) { Imagen.from_local('spec/fixtures/branch_ignored.rb') }
    let(:simplecov) do
      simplecov_coverage_fixture 'spec/fixtures/branch_ignored_coverage/branch_ignored_test.json'
    end
    let(:coverage) { simplecov }

    it 'accepts ignored branches with present line coverage (:nocov: edge case)' do
      nodes = ast.find_all(->(node) { !node.is_a?(Imagen::Node::Root) })
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
  end

  context 'with skipped lines in coverage' do
    let(:file_path) { 'test.rb' }
    let(:source_file) do
      "def foo\n  " \
        "puts 'bar'\n" \
        "end\n"
    end
    let(:ast) do
      root = Imagen::Node::Root.new
      Imagen::Visitor.traverse(Imagen::AST::Parser.parse(source_file, file_path), root)
    end
    let(:mock_coverage) do
      coverage_data = [
        [1, 1], [2, 0], [3, 1]
      ]
      double('coverage', coverage: coverage_data, skipped?: true)
    end

    it 'handles skipped lines correctly' do
      node = ast.find_all(->(n) { n.name == 'foo' }).first
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
      root = Imagen::Node::Root.new
      Imagen::Visitor.traverse(Imagen::AST::Parser.parse(source_file, file_path), root)
    end
    let(:mock_coverage_with_skipped) do
      coverage_data = [
        [2, 0], [3, 1] # Only lines that are inside the method body
      ]
      coverage_mock = double('coverage')
      allow(coverage_mock).to receive(:coverage).with(file_path).and_return(coverage_data)
      allow(coverage_mock).to receive(:skipped?).with(file_path, 2).and_return(true)
      allow(coverage_mock).to receive(:skipped?).with(file_path, 3).and_return(false)
      coverage_mock
    end

    it 'marks skipped lines as covered and skips to next iteration' do
      node = ast.find_all(->(n) { n.name == 'skipped_method' }).first
      result = described_class.new(node, mock_coverage_with_skipped, file_path)

      # Line 2 should be marked as covered (1) due to being skipped
      # Line 3 should be marked as covered (1) normally
      # This should result in 2/2 = 1.0 coverage
      expect(result.coverage_f).to eq(1.0)
    end
  end

  context 'with pretty print formatting' do
    let(:ast) { Imagen.from_local('spec/fixtures/class.rb') }
    let(:coverage) { lcov }

    it 'handles different line types in pretty_print' do
      node = ast.find_all(with_name('BaconClass')).first
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

      ast = Imagen::Node::Root.new
      Imagen::Visitor.traverse(Imagen::AST::Parser.parse(source_file, file_path), ast)
      node = ast.find_all(->(n) { n.name == 'test_method' }).first

      # Create mock coverage that will return true for skipped? on line 2
      mock_coverage = double('coverage')
      coverage_data = [[2, 0], [3, 1]] # Lines within the method
      allow(mock_coverage).to receive(:coverage).with(file_path).and_return(coverage_data)
      allow(mock_coverage).to receive(:skipped?).and_return(false) # Default to false
      allow(mock_coverage).to receive(:skipped?).with(file_path, 2).and_return(true)

      result = described_class.new(node, mock_coverage, file_path)

      # This should trigger the skipped line formatting (lines 106-108)
      pretty_output = result.pretty_print
      expect(pretty_output).to include('skipped with :nocov:')
    end
  end
end
