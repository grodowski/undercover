# frozen_string_literal: true

require 'spec_helper'
require 'undercover/ast_branch_annotator'

describe Undercover::AstBranchAnnotator do
  def parse(src)
    Imagen::AST::Parser.parse(src, 'test.rb')
  end

  def annotate(src)
    described_class.call(parse(src))
  end

  it 'returns empty hash for nil' do
    expect(described_class.call(nil)).to eq({})
  end

  it 'returns empty hash for non-AST values' do
    expect(described_class.call('string')).to eq({})
  end

  describe 'if/else' do
    it 'labels if keyword line with condition source' do
      info = annotate("if x\n  a\nelse\n  b\nend")
      expect(info[1]).to eq('if x')
    end

    it 'labels else keyword line' do
      info = annotate("if x\n  a\nelse\n  b\nend")
      expect(info[3]).to eq('else')
    end

    it 'labels unless keyword' do
      info = annotate("unless x\n  a\nend")
      expect(info[1]).to eq('unless x')
    end

    it 'handles if without else' do
      info = annotate("if x\n  a\nend")
      expect(info[1]).to eq('if x')
      expect(info.key?(3)).to be false
    end

    it 'labels elsif lines' do
      info = annotate("if x\n  a\nelsif y\n  b\nend")
      expect(info[3]).to eq('elsif y')
    end
  end

  describe 'ternary' do
    it 'labels the question mark line with condition' do
      info = annotate('x ? a : b')
      expect(info[1]).to eq('? x')
    end

    it 'labels the colon line separately when on a different line' do
      info = annotate("x ?\n  a :\n  b")
      expect(info[2]).to eq(':')
    end
  end

  describe 'case/when' do
    it 'labels each when line with its condition' do
      info = annotate("case x\nwhen :foo\n  a\nwhen :bar\n  b\nend")
      expect(info[2]).to eq('when :foo')
      expect(info[4]).to eq('when :bar')
    end
  end

  describe '&& and ||' do
    # Ruby's Coverage module does not track && / || as branch points —
    # only if/unless/case/ternary produce BRDA entries. Annotating these
    # lines would produce labels that never match any coverage entry.
    it 'does not annotate && (not a Ruby coverage branch)' do
      info = annotate('a && b')
      expect(info).to be_empty
    end

    it 'does not annotate || (not a Ruby coverage branch)' do
      info = annotate('a || b')
      expect(info).to be_empty
    end
  end

  describe 'if with unrecognized location map' do
    it 'silently skips without raising (e.g. pattern-match guards)' do
      condition = parse('x')
      unknown_map = Struct.new(:node).new # not Condition or Ternary
      if_node = Parser::AST::Node.new(:if, [condition], {location: unknown_map})

      expect(described_class.call(if_node)).to eq({})
    end
  end

  it 'recurses into nested constructs' do
    src = "def foo\n  if x\n    a\n  else\n    b\n  end\nend"
    info = annotate(src)
    expect(info[2]).to eq('if x')
    expect(info[4]).to eq('else')
  end
end
