# frozen_string_literal: true

require 'spec_helper'
require 'undercover'

describe Undercover::Node do
  def summary(source)
    all_nodes('inline.rb', source).map { |n| [n.human_name, n.name, n.first_line, n.last_line, n.empty_def?] }
  end

  it 'builds classes, modules, methods and blocks as a tree' do
    roots = described_class.parse(File.read('spec/fixtures/class.rb'), 'spec/fixtures/class.rb')
    expect(roots.map(&:name)).to eq(['BaconClass'])
    expect(roots.first.children.map { |n| [n.human_name, n.name] })
      .to eq([['class method', 'bar'], ['instance method', 'foo'], %w[class BaconChildClass]])
    expect(roots.first.file_path).to eq('spec/fixtures/class.rb')
    expect(roots.first.find_all(with_name('foo')).map(&:human_name)).to eq(['instance method'])
  end

  it 'names classes and modules by their last constant' do
    expect(summary("module A::B\n  class self::C < D\n  end\nend\n"))
      .to eq([['module', 'B', 1, 4, false], ['class', 'C', 2, 3, true]])
  end

  it 'reports singleton class methods as instance methods' do
    expect(summary("class << self\n  def foo; end\nend\ndef obj.bar = 1\ndef ~@; end\n"))
      .to eq([['instance method', 'foo', 2, 2, true], ['class method', 'bar', 4, 4, false],
              ['instance method', '~@', 5, 5, true]])
  end

  it 'spans a block over its whole method call' do
    expect(summary("items\n  .map do |x|\n  end\nsuper { }\nsuper(1) { 2 }\n"))
      .to eq([['block', 'block (x)', 1, 3, true], ['block', 'block', 4, 4, true], ['block', 'block', 5, 5, false]])
  end

  it 'names blocks by their explicit parameters' do
    source = <<~RUBY
      a { |(k, v), h, *, **nil, &| h }
      b { |x, y = 1, *r, z, k:, o: 2, **kw, &blk; local| x }
      c { |x,| x }
      d { it }
      e { _1 + _2 }
      f = ->(x) { x }
      g = -> { _1 }
      h { |; local| }
    RUBY
    expect(all_nodes('inline.rb', source).map(&:name))
      .to eq(['block ((k, v), h, , , )', 'block (x, y, r, z, k, o, kw, blk, local)', 'block (x)',
              'block', 'block', 'block (x)', 'block', 'block (local)'])
  end

  it 'lists nested blocks in arguments and receivers after their outer block' do
    expect(all_nodes('inline.rb', "a.map { 1 }.select(b { 2 }) { |y| y }\n").map(&:name))
      .to eq(['block (y)', 'block', 'block'])
  end

  it 'returns source lines with numbers' do
    node = all_nodes('inline.rb', "\ndef foo\n  1\nend\n").first
    expect(node.source_lines_with_numbers).to eq([[2, 'def foo'], [3, '  1'], [4, 'end']])
  end

  it 'parses Ruby 4.0 syntax that the parser gem rejected' do
    if RUBY_VERSION < '4.0' && Gem::Version.new(Prism::VERSION) >= Gem::Version.new('2')
      skip 'Prism 2 parses with the syntax of the running Ruby'
    end

    expect(summary("def ok?\n  a\n    && b\nend\n")).to eq([['instance method', 'ok?', 1, 4, false]])
  end

  it 'rejects a top-level yield, which is invalid Ruby outside of a template' do
    expect { described_class.parse("yield\n", 'top.rb') }.to raise_error(described_class::ParseError, /Invalid yield/)
  end

  it 'raises a ParseError naming the first error and its line' do
    expect { described_class.parse("def foo\n  bar(\nend\n", 'broken.rb') }
      .to raise_error(described_class::ParseError, /on line \d/)
  end
end
