# frozen_string_literal: true

module Undercover
  # Parses a changed file into Undercover::Result nodes. ERB templates go through
  # ErbExtractor first, which turns a template into Ruby with line positions preserved
  # so the parser can place nodes back onto the original template's line numbers.
  #
  # Expects the host to provide #code_dir, #coverage_adapter, #loaded_files and #erb_parse_failures.
  module FileLoader
    ERB_EXTENSION = '.erb'

    def load_and_parse_file(filepath)
      key = filepath.gsub(/^\.\//, '')
      return if loaded_files.key?(key)

      loaded_files[key] = nil
      nodes = filepath.end_with?(ERB_EXTENSION) ? load_erb_file(key, filepath) : load_ruby_file(key, filepath)
      loaded_files[key] = build_results(nodes, filepath) if nodes&.any?
    end

    private

    def load_erb_file(key, filepath)
      return unless coverage_adapter.erb_coverage?

      full_path = File.join(code_dir, filepath)
      return unless File.exist?(full_path)

      all_nodes(ErbNode.parse(File.read(full_path), full_path))
    rescue StandardError => e
      erb_parse_failures << key
      warn "#{key}: ERB parsing failed (#{e.message})"
    end

    def load_ruby_file(key, filepath)
      all_nodes(Node.parse_file(File.join(code_dir, filepath)))
    rescue Node::ParseError => e
      warn "#{key}: Ruby parsing failed (#{e.message})"
    end

    def all_nodes(roots)
      roots.flat_map { _1.find_all(->(_node) { true }) }
    end

    # Indexes the file's coverage once for all of its nodes
    def build_results(nodes, filepath)
      index = CoverageIndex.new(coverage_adapter.coverage(filepath))
      nodes.map { |node| Result.new(node, coverage_adapter, filepath, coverage_index: index) }
    end
  end
end
