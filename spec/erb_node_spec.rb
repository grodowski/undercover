# frozen_string_literal: true

require 'spec_helper'
require 'undercover'

describe Imagen::Node::ErbFile do
  let(:code_dir) { 'spec/fixtures' }
  let(:filepath) { 'test.html.erb' }
  subject(:erb_file) { described_class.new(filepath, code_dir) }

  describe '#build_from_ruby_source' do
    it 'parses ERB and builds child nodes for block constructs' do
      source = File.read(File.join(code_dir, filepath))
      ruby_source = Herb.extract_ruby(source)
      erb_file.build_from_ruby_source(ruby_source)

      expect(erb_file.children).not_to be_empty
      expect(erb_file.children).to all(be_a(Imagen::Node::ErbNode))
    end

    it 'returns self with no children on syntax error' do
      erb_file.build_from_ruby_source('if (')
      expect(erb_file.children).to be_empty
    end
  end

  describe '#human_name' do
    it { expect(erb_file.human_name).to eq('erb file') }
  end

  describe '#first_line / #last_line' do
    it { expect(erb_file.first_line).to be_nil }
    it { expect(erb_file.last_line).to be_nil }
  end
end

describe Imagen::Node::ErbNode do
  let(:code_dir) { 'spec/fixtures' }
  let(:filepath) { 'test.html.erb' }
  let(:full_path) { File.join(code_dir, filepath) }
  let(:ruby_source) { Herb.extract_ruby(File.read(full_path)) }
  let(:erb_file) do
    Imagen::Node::ErbFile.new(filepath, code_dir).build_from_ruby_source(ruby_source)
  end
  let(:nodes) { erb_file.find_all(->(n) { !n.is_a?(Imagen::Node::ErbFile) }) }

  it 'finds all block constructs in the fixture' do
    types = nodes.map { |n| n.ast_node.type }
    expect(types).to include(:if, :block, :while, :case)
  end

  describe 'if node' do
    subject(:node) { nodes.find { |n| n.ast_node.type == :if } }

    it { expect(node.name).to eq('if') }
    it { expect(node.human_name).to eq('if block') }
    it { expect(node.first_line).to eq(6) }
    it { expect(node.last_line).to eq(10) }
    it { expect(node.empty_def?).to be(false) }

    it 'returns source lines from the original ERB file' do
      lines = node.source_lines
      expect(lines.first).to include('if @user')
      expect(lines.last).to include('end')
    end

    it 'returns source_lines_with_numbers starting at first_line' do
      pairs = node.source_lines_with_numbers
      expect(pairs.first[0]).to eq(6)
      expect(pairs.last[0]).to eq(10)
    end
  end

  describe 'each do block node' do
    subject(:node) { nodes.find { |n| n.ast_node.type == :block } }

    it { expect(node.name).to eq('block (item)') }
    it { expect(node.human_name).to eq('block block') }
    it { expect(node.first_line).to eq(11) }
    it { expect(node.last_line).to eq(13) }
  end

  describe 'while node' do
    subject(:node) { nodes.find { |n| n.ast_node.type == :while } }

    it { expect(node.name).to eq('while') }
    it { expect(node.human_name).to eq('while block') }
    it { expect(node.first_line).to eq(14) }
    it { expect(node.last_line).to eq(16) }
  end

  describe 'case node' do
    subject(:node) { nodes.find { |n| n.ast_node.type == :case } }

    it { expect(node.name).to eq('case') }
    it { expect(node.human_name).to eq('case block') }
    it { expect(node.first_line).to eq(17) }
    it { expect(node.last_line).to eq(20) }
  end

  describe 'source_lines with missing file' do
    it 'returns empty array when the source file does not exist' do
      node = nodes.first
      allow(node.ast_node.location.expression.source_buffer).to receive(:name).and_return('/nonexistent/file.erb')
      expect(node.source_lines).to eq([])
    end
  end
end

describe Undercover::ErbVisitor do
  let(:code_dir) { 'spec/fixtures' }
  let(:filepath) { 'test.html.erb' }
  let(:full_path) { File.join(code_dir, filepath) }
  let(:ruby_source) { Herb.extract_ruby(File.read(full_path)) }
  let(:erb_file) do
    Imagen::Node::ErbFile.new(filepath, code_dir).build_from_ruby_source(ruby_source)
  end

  it 'does not create a separate node for elsif branches' do
    nodes = erb_file.find_all(->(n) { !n.is_a?(Imagen::Node::ErbFile) })
    if_nodes = nodes.select { |n| n.ast_node.type == :if }
    # test.html.erb has one if/else — no elsif — so exactly one if node
    expect(if_nodes.size).to eq(1)
  end

  context 'with an elsif branch' do
    let(:erb_source) do
      <<~ERB
        <% if @a %>
          <p>A</p>
        <% elsif @b %>
          <p>B</p>
        <% end %>
      ERB
    end

    it 'collapses if/elsif into a single node' do
      ruby_source = Herb.extract_ruby(erb_source)
      root = Imagen::Node::ErbFile.new('inline.erb', '.')
      root.instance_variable_set(:@full_path, File::NULL)
      Undercover::ErbVisitor.traverse(Imagen::AST::Parser.parse(ruby_source, File::NULL), root)

      if_nodes = root.find_all(->(n) { !n.is_a?(Imagen::Node::ErbFile) })
                     .select { |n| n.ast_node.type == :if }
      expect(if_nodes.size).to eq(1)
    end
  end

  context 'with a no-args block' do
    let(:erb_source) do
      <<~ERB
        <% [1, 2].each do %>
          <p>item</p>
        <% end %>
      ERB
    end

    it 'names the block without args' do
      ruby_source = Herb.extract_ruby(erb_source)
      root = Imagen::Node::ErbFile.new('inline.erb', '.')
      root.instance_variable_set(:@full_path, File::NULL)
      Undercover::ErbVisitor.traverse(Imagen::AST::Parser.parse(ruby_source, File::NULL), root)

      block_node = root.children.find { |n| n.ast_node.type == :block }
      expect(block_node.name).to eq('block')
    end
  end
end

describe 'Imagen::Node::ErbNode args_list' do
  it 'returns nil when block AST node has no :args child' do
    # Construct a synthetic :block node with no :args child to exercise the
    # `return unless args_node` guard in args_list.
    synthetic = Parser::AST::Node.new(:block, [])
    node = Imagen::Node::ErbNode.new
    expect(node.send(:args_list, synthetic)).to be_nil
  end
end

describe 'Undercover::Report load_erb_file rescue' do
  let(:options) do
    Undercover::Options.new.tap do |opt|
      opt.path = '.'
      opt.git_dir = 'spec/fixtures/test.git'
      opt.simplecov_resultset = 'spec/fixtures/erb_coverage.json'
    end
  end
  let(:changeset) do
    mock_changeset = instance_double(Undercover::Changeset)
    allow(mock_changeset).to receive(:each_changed_line).and_yield('spec/fixtures/test.html.erb', 8)
    allow(mock_changeset).to receive(:filter_with)
    mock_changeset
  end
  let(:report) do
    Undercover::Report.new(changeset, options, simplecov_coverage_fixture('spec/fixtures/erb_coverage.json'))
  end

  it 'warns and skips the file when ERB parsing raises' do
    allow(Herb).to receive(:extract_ruby).and_raise(StandardError, 'parse error')
    expect { report.build }.to output(/ERB parsing failed/).to_stderr
    expect(report.results).to be_empty
  end

  it 'skips silently when the ERB file does not exist on disk' do
    changeset = instance_double(Undercover::Changeset)
    allow(changeset).to receive(:each_changed_line)
      .and_yield('spec/fixtures/nonexistent.erb', 1)
    allow(changeset).to receive(:filter_with)

    nonexistent_report = Undercover::Report.new(
      changeset, options,
      simplecov_coverage_fixture('spec/fixtures/erb_coverage.json')
    )
    expect { nonexistent_report.build }.not_to output.to_stderr
    expect(nonexistent_report.results).to be_empty
  end
end
