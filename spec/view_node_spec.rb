# frozen_string_literal: true

require 'spec_helper'
require 'undercover'

describe Undercover::ViewNode do
  let(:code_dir) { 'spec/fixtures' }
  let(:file_path) { 'test.html.erb' }
  let(:node) { described_class.new(file_path, code_dir) }

  describe '#first_line' do
    it 'returns 1' do
      expect(node.first_line).to eq(1)
    end
  end

  describe '#last_line' do
    it 'returns the number of lines in the file' do
      expect(node.last_line).to eq(12)
    end

    context 'when file does not exist' do
      let(:file_path) { 'nonexistent.html.erb' }

      it 'returns 0' do
        expect(node.last_line).to eq(0)
      end
    end
  end

  describe '#name' do
    it 'returns the filename' do
      expect(node.name).to eq('test.html.erb')
    end

    context 'with nested path' do
      let(:file_path) { 'app/views/users/show.html.erb' }

      it 'returns only the filename' do
        expect(node.name).to eq('show.html.erb')
      end
    end
  end

  describe '#human_name' do
    it 'returns erb view for .erb files' do
      expect(node.human_name).to eq('erb view')
    end

    context 'with .haml extension' do
      let(:file_path) { 'test.haml' }

      it 'returns haml view' do
        expect(node.human_name).to eq('haml view')
      end
    end

    context 'with .slim extension' do
      let(:file_path) { 'test.slim' }

      it 'returns slim view' do
        expect(node.human_name).to eq('slim view')
      end
    end

    context 'with .jbuilder extension' do
      let(:file_path) { 'test.json.jbuilder' }

      it 'returns jbuilder view' do
        expect(node.human_name).to eq('jbuilder view')
      end
    end
  end

  describe '#empty_def?' do
    it 'returns false' do
      expect(node.empty_def?).to be(false)
    end
  end

  describe '#source_lines_with_numbers' do
    it 'returns array of [line_number, source_line] tuples' do
      lines = node.source_lines_with_numbers
      expect(lines.first).to eq([1, '<html>'])
      expect(lines.last).to eq([12, '</html>'])
      expect(lines.size).to eq(12)
    end

    it 'preserves line numbers correctly' do
      lines = node.source_lines_with_numbers
      lines.each_with_index do |(num, _line), idx|
        expect(num).to eq(idx + 1)
      end
    end

    context 'when file does not exist' do
      let(:file_path) { 'nonexistent.html.erb' }

      it 'returns empty array' do
        expect(node.source_lines_with_numbers).to eq([])
      end
    end
  end

  describe 'template type support' do
    shared_examples 'a supported view template' do |extension, human_name, line_count|
      let(:file_path) { "test#{extension}" }

      it "parses #{extension} files correctly" do
        expect(node.first_line).to eq(1)
        expect(node.last_line).to eq(line_count)
        expect(node.human_name).to eq(human_name)
        expect(node.source_lines_with_numbers.size).to eq(line_count)
      end
    end

    it_behaves_like 'a supported view template', '.html.erb', 'erb view', 12
    it_behaves_like 'a supported view template', '.haml', 'haml view', 8
    it_behaves_like 'a supported view template', '.slim', 'slim view', 8
    it_behaves_like 'a supported view template', '.json.jbuilder', 'jbuilder view', 12
  end
end
