# frozen_string_literal: true

require 'prism'

module Undercover
  # A class, module, method or block parsed from a Ruby file, with the line range
  # undercover checks coverage for. Blocks span their whole method call, receiver included.
  class Node
    class ParseError < StandardError; end

    HUMAN_NAMES = {
      class: 'class',
      module: 'module',
      instance_method: 'instance method',
      class_method: 'class method',
      block: 'block'
    }.freeze

    attr_reader :kind, :name, :prism_node, :file_path, :children

    # @param source_lines [Array<String>] the lines nodes print, when not the parsed source's own
    # @return [Array<Node>] top-level nodes, each with its nested nodes as children
    def self.parse(source, file_path, visitor_class: NodeVisitor, source_lines: source.lines.map(&:chomp),
                   partial_script: false)
      result = Prism.parse(source, filepath: file_path, partial_script:)
      if result.failure?
        error = result.errors.first
        raise ParseError, "#{error.message} on line #{error.location.start_line}"
      end

      visitor_class.new(file_path, source_lines).tap { result.value.accept(_1) }.roots
    end

    def self.parse_file(path)
      parse(File.read(path), path)
    end

    def initialize(kind, name, prism_node, file_path, source_lines, empty:) # rubocop:disable Metrics/ParameterLists
      @kind = kind
      @name = name
      @prism_node = prism_node
      @file_path = file_path
      @file_lines = source_lines
      @empty = empty
      @children = []
    end

    def human_name
      HUMAN_NAMES.fetch(kind)
    end

    def first_line
      prism_node.location.start_line
    end

    def last_line
      prism_node.location.end_line
    end

    def empty_def?
      @empty
    end

    def source_lines
      @file_lines[(first_line - 1)..(last_line - 1)]
    end

    def source_lines_with_numbers
      (first_line..last_line).zip(source_lines)
    end

    def find_all(matcher, ret = [])
      ret << self if matcher.call(self)
      children.each { |child| child.find_all(matcher, ret) }
      ret
    end
  end
end
