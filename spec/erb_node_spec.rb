# frozen_string_literal: true

require 'spec_helper'
require 'undercover'

def parse_erb(erb_source, path = File::NULL)
  Undercover::ErbNode.parse(erb_source, path).flat_map { |root| root.find_all(->(_) { true }) }
end

describe Undercover::ErbNode do
  let(:full_path) { 'spec/fixtures/test.html.erb' }
  let(:nodes) { parse_erb(File.read(full_path), full_path) }

  it 'finds all block constructs in the fixture' do
    expect(nodes).to all(be_a(described_class))
    expect(nodes.map(&:kind)).to include(:if, :block, :while, :case)
  end

  it 'raises a parse error on invalid Ruby' do
    expect { parse_erb('<% if ( %>') }
      .to raise_error(Undercover::Node::ParseError, /unexpected end-of-input.* on line 2/)
  end

  describe 'if node' do
    subject(:node) { nodes.find { |n| n.kind == :if } }

    it { expect(node.name).to eq('if') }
    it { expect(node.human_name).to eq('if block') }
    it { expect(node.first_line).to eq(6) }
    it { expect(node.last_line).to eq(10) }

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
    subject(:node) { nodes.find { |n| n.kind == :block } }

    it { expect(node.name).to eq('block (item)') }
    it { expect(node.human_name).to eq('block block') }
    it { expect(node.first_line).to eq(11) }
    it { expect(node.last_line).to eq(13) }
  end

  describe 'while node' do
    subject(:node) { nodes.find { |n| n.kind == :while } }

    it { expect(node.name).to eq('while') }
    it { expect(node.human_name).to eq('while block') }
    it { expect(node.first_line).to eq(14) }
    it { expect(node.last_line).to eq(16) }
  end

  describe 'case node' do
    subject(:node) { nodes.find { |n| n.kind == :case } }

    it { expect(node.name).to eq('case') }
    it { expect(node.human_name).to eq('case block') }
    it { expect(node.first_line).to eq(17) }
    it { expect(node.last_line).to eq(20) }
  end

  it 'parses a top-level yield, as in a layout' do
    expect(parse_erb("<%= yield %>\n<% if x %>\n<% end %>\n").map(&:name)).to eq(['if'])
  end
end

describe Undercover::ErbVisitor do
  it 'does not create a separate node for elsif branches' do
    if_nodes = parse_erb(File.read('spec/fixtures/test.html.erb')).select { |n| n.kind == :if }
    # test.html.erb has one if/else — no elsif — so exactly one if node
    expect(if_nodes.size).to eq(1)
  end

  it 'collapses if/elsif into a single node and finds blocks in its branches' do
    erb = <<~ERB
      <% if @a %>
        <p>A</p>
      <% elsif @b %>
        <% @items.each do |item| %>
          <p><%= item %></p>
        <% end %>
      <% end %>
    ERB
    expect(parse_erb(erb).map { |n| [n.name, n.first_line, n.last_line] })
      .to eq([['if', 1, 7], ['block (item)', 4, 6]])
  end

  it 'reports unless and until' do
    erb = <<~ERB
      <% unless @a %>
        <% until @b %>
          <p>B</p>
        <% end %>
      <% end %>
    ERB
    expect(parse_erb(erb).map { |n| [n.human_name, n.name, n.first_line, n.last_line] })
      .to eq([['unless block', 'unless', 1, 5], ['until block', 'until', 2, 4]])
  end

  it 'names the block without args' do
    erb = <<~ERB
      <% [1, 2].each do %>
        <p>item</p>
      <% end %>
    ERB
    expect(parse_erb(erb).map(&:name)).to eq(['block'])
  end

  it 'reports methods defined in a template as regular nodes' do
    nodes = parse_erb("<% def helper %>\n  <p>x</p>\n<% end %>\n")
    expect(nodes.map { |n| [n.class, n.human_name, n.name] })
      .to eq([[Undercover::Node, 'instance method', 'helper']])
  end
end

describe Undercover::ErbExtractor do
  def block_lines(erb_source)
    parse_erb(erb_source).select { |n| n.kind == :block }.map { |n| [n.first_line, n.last_line] }
  end

  it 'parses form_with with a do |f| block' do
    erb = <<~ERB
      <%= form_with model: @user do |f| %>
        <%= f.text_field :name %>
      <% end %>
    ERB
    expect(block_lines(erb)).to eq([[1, 3]])
  end

  it 'parses a multi-line form_with block' do
    erb = <<~ERB
      <%= form_with model: @user,
                    url: users_path do |f| %>
        <%= f.submit %>
      <% end %>
    ERB
    expect(block_lines(erb)).to eq([[1, 4]])
  end

  it 'parses link_to and turbo_frame_tag do blocks' do
    erb = <<~ERB
      <%= turbo_frame_tag "user" do %>
        <%= link_to user_path(@user) do %>
          <span>Profile</span>
        <% end %>
      <% end %>
    ERB
    expect(block_lines(erb)).to eq([[1, 5], [2, 4]])
  end

  it 'parses content_tag with a brace block' do
    erb = <<~ERB
      <%= content_tag(:ul) { |x| %>
        <li>item</li>
      <% } %>
    ERB
    expect(block_lines(erb)).to eq([[1, 3]])
  end

  it 'parses a block opened by an unescaped <%== tag' do
    erb = <<~ERB
      <%== tag.div do %>
        <p>raw</p>
      <% end %>
    ERB
    expect(block_lines(erb)).to eq([[1, 3]])
  end

  it 'places an if nested inside a block helper on its own lines' do
    nodes = parse_erb(File.read('spec/fixtures/block_helper.html.erb'))
    expect(nodes.map { |n| [n.kind, n.first_line, n.last_line] }).to eq([[:block, 1, 6], [:if, 3, 5]])
  end

  it 'leaves non-block expressions as buffered output' do
    expect(described_class.call("<%= link_to 'Home', root_path %>\n"))
      .to include("_buf << ( link_to 'Home', root_path ).to_s")
  end

  it 'parses a case whose first when is in a separate tag' do
    erb = <<~ERB
      <% case @status %>
      <% when :ok %>
        <p>OK</p>
      <% end %>
    ERB
    expect(parse_erb(erb).map { |n| [n.kind, n.first_line, n.last_line] }).to eq([[:case, 1, 4]])
  end
end

describe 'Undercover::Report load_erb_file rescue' do
  let(:options) do
    Undercover::Options.new.tap do |opt|
      opt.git_dir = 'spec/fixtures/test.git'
      opt.simplecov_resultset = 'spec/fixtures/erb_coverage.json'
    end
  end
  let(:changeset) do
    mock_changeset = instance_double(Undercover::Changeset)
    allow(mock_changeset).to receive(:each_changed_line).and_yield('spec/fixtures/test.html.erb', 8)
    allow(mock_changeset).to receive(:filter_with)
    allow(mock_changeset).to receive(:repo_workdir).and_return('.')
    allow(mock_changeset).to receive(:head_path?).and_return(false)
    allow(mock_changeset).to receive(:file_paths).and_return(['spec/fixtures/test.html.erb'])
    mock_changeset
  end
  let(:report) do
    Undercover::Report.new(changeset, options, simplecov_coverage_fixture('spec/fixtures/erb_coverage.json'))
  end

  it 'warns and skips the file when ERB parsing raises' do
    allow(Undercover::ErbExtractor).to receive(:call).and_raise(StandardError, 'parse error')
    expect { report.build }.to output(/ERB parsing failed/).to_stderr
    expect(report.results).to be_empty
    expect(report.erb_parse_failures).to eq(['spec/fixtures/test.html.erb'])
  end

  it 'parses and warns about an unparseable template once, however many lines changed' do
    template = 'spec/fixtures/unparseable.html.erb'
    allow(changeset).to receive(:each_changed_line).and_yield(template, 1).and_yield(template, 2)
                                                   .and_yield(template, 3)
    allow(changeset).to receive(:file_paths).and_return([template])
    expect(Undercover::ErbExtractor).to receive(:call).once.and_call_original

    expect { report.build }
      .to output("#{template}: ERB parsing failed (unexpected end-of-input, assuming it is closing " \
                 "the parent top level context on line 5)\n").to_stderr
    expect(report.results).to be_empty
    expect(report.erb_parse_failures).to eq([template])
  end

  it 'has no parse failures for a template that parses' do
    report.build
    expect(report.erb_parse_failures).to be_empty
  end

  it 'skips silently when the ERB file does not exist on disk' do
    changeset = instance_double(Undercover::Changeset)
    allow(changeset).to receive(:each_changed_line)
      .and_yield('spec/fixtures/nonexistent.erb', 1)
    allow(changeset).to receive(:filter_with)
    allow(changeset).to receive(:repo_workdir).and_return('.')
    allow(changeset).to receive(:head_path?).and_return(false)
    allow(changeset).to receive(:file_paths).and_return(['spec/fixtures/nonexistent.erb'])

    nonexistent_report = Undercover::Report.new(
      changeset, options,
      simplecov_coverage_fixture('spec/fixtures/erb_coverage.json')
    )
    expect { nonexistent_report.build }.not_to output.to_stderr
    expect(nonexistent_report.results).to be_empty
  end
end
