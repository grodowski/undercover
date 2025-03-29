# frozen_string_literal: true

require 'spec_helper'
require 'undercover'

describe Undercover::Result do
  let(:ast) { Imagen.from_local('spec/fixtures/class.rb') }
  let(:lcov) do
    Undercover::LcovParser.parse('spec/fixtures/fixtures.lcov')
  end
  let(:coverage) { lcov.source_files['class.rb'] }

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
    let(:coverage) { lcov.source_files['empty_class_def.rb'] }

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
    let(:coverage) { lcov.source_files['module.rb'] }

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
    let(:coverage) { lcov.source_files['one_line_block.rb'] }

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
    let(:coverage) { lcov.source_files['single_line.rb'] }

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
    let(:coverage) { lcov.source_files['method_block_multi.rb'] }

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
    let(:coverage) { lcov.source_files['method_block_multi.rb'] }

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
    let(:coverage) { lcov.source_files['def_single_line.rb'] }

    it "doesn't report false positive on block" do
      nodes = ast.find_all(->(node) { !node.is_a?(Imagen::Node::Root) })
      nodes.each do |node|
        result = described_class.new(node, coverage, 'method_block_multi.rb')
        expect(result.uncovered?(1)).to be_falsy
        expect(result.coverage_f).to eq(1.0)
      end
    end
  end
end
