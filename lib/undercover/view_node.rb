# frozen_string_literal: true

module Undercover
  class ViewNode
    attr_reader :file_path

    def initialize(file_path, code_dir)
      @file_path = file_path
      @full_path = File.join(code_dir, file_path)
    end

    def first_line
      1
    end

    def last_line
      source_lines.size
    end

    def name
      File.basename(file_path)
    end

    def human_name
      "#{File.extname(file_path).delete_prefix('.')} view"
    end

    def empty_def?
      false
    end

    def source_lines_with_numbers
      source_lines.map.with_index(1) { |line, num| [num, line] }
    end

    private

    def source_lines
      @source_lines ||= File.exist?(@full_path) ? File.readlines(@full_path, chomp: true) : []
    end
  end
end
