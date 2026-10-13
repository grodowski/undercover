# frozen_string_literal: true

require 'spec_helper'

# These tests use the the fixture repo test.git
# use `git --git-dir=test.git <command>` to inspect
# or modify it.
describe Undercover::Changeset do
  it 'diffs index and staging area against HEAD' do
    changeset = Undercover::Changeset.new(
      'spec/fixtures/test.git'
    )

    expect(changeset.file_paths).to match_array(
      %w[file_one file_two staged_file class.rb module.rb sinatra.rb]
    )

    file_two_lines = []
    changeset.each_changed_line do |filepath, line_no|
      file_two_lines << line_no if filepath == 'file_two'
    end
    expect(file_two_lines).to eq([7, 10, 11])
  end

  it 'has all the changes agains base with compare_base arg' do
    changeset = Undercover::Changeset.new(
      'spec/fixtures/test.git',
      'master'
    )

    expect(changeset.file_paths).to match_array(
      %w[file_one file_three file_two staged_file class.rb module.rb sinatra.rb]
    )

    file_two_lines = []
    file_three_lines = []
    changeset.each_changed_line do |filepath, line_no|
      file_two_lines << line_no if filepath == 'file_two'
      file_three_lines << line_no if filepath == 'file_three'
    end
    expect(file_two_lines).to eq([7, 10, 11])
    expect(file_three_lines).to eq([1, 2, 3, 4, 5, 6])
  end

  it 'ignores the index and working tree with commits_only' do
    changeset = Undercover::Changeset.new('spec/fixtures/test.git', 'master', commits_only: true)

    expect(changeset.file_paths).to match_array(%w[file_three module.rb])

    file_three_lines = []
    changeset.each_changed_line do |filepath, line_no|
      file_three_lines << line_no if filepath == 'file_three'
    end
    expect(file_three_lines).to eq([1, 2, 3, 4, 5, 6])
  end

  it 'requires a compare_base with commits_only' do
    expect { Undercover::Changeset.new('spec/fixtures/test.git', commits_only: true) }
      .to raise_error(ArgumentError, 'commits_only requires a compare_base')
  end

  it 'answers whether HEAD has a path, whatever the working tree holds' do
    changeset = Undercover::Changeset.new('spec/fixtures/test.git')

    expect(changeset.head_path?('module.rb')).to be(true)
    expect(changeset.head_path?('staged_file')).to be(false)
    expect(changeset.head_path?('nope/missing.rb')).to be(false)
  end

  it 'has a last_modified when changes are present' do
    changeset = Undercover::Changeset.new(
      'spec/fixtures/test.git',
      'master'
    )

    Timecop.freeze do
      file_paths = changeset.file_paths.map { |p| "spec/fixtures/#{p}" }
      FileUtils.touch(file_paths, mtime: Time.now)
      expect(changeset.last_modified.to_i).to eq(Time.now.to_i)
    end
  end

  it 'has a default last_modified with no changes' do
    changeset = Undercover::Changeset.new('spec/fixtures/empty.git', 'master')
    expect(changeset.last_modified).to eq(Undercover::Changeset::T_ZERO)
  end

  describe 'filtering' do
    it 'filters files using FilterSet in each_changed_line' do
      filter_set = Undercover::FilterSet.new(['*.rb'], ['*_spec.rb'], [])
      changeset = Undercover::Changeset.new('spec/fixtures/test.git', 'master', filter_set)

      yielded_files = []
      changeset.each_changed_line do |filepath, _line_no|
        yielded_files << filepath
      end

      expect(yielded_files.uniq).to match_array(['class.rb', 'module.rb', 'sinatra.rb'])
      expect(yielded_files.uniq).not_to include('file_one', 'file_two', 'file_three', 'staged_file')
    end

    it 'filters files using FilterSet with brace expansion' do
      filter_set = Undercover::FilterSet.new(['*.{rb,js}'], ['*_spec.rb'], [])
      changeset = Undercover::Changeset.new('spec/fixtures/test.git', 'master', filter_set)

      yielded_files = []
      changeset.each_changed_line do |filepath, _line_no|
        yielded_files << filepath
      end

      expect(yielded_files.uniq).to match_array(['class.rb', 'module.rb', 'sinatra.rb'])
      expect(yielded_files.uniq).not_to include('file_one', 'file_two', 'file_three', 'staged_file')
    end
  end

  describe 'validate' do
    let(:report_path) { 'spec/fixtures/sample.lcov' }

    it 'returns :no_changes with empty files' do
      changeset = Undercover::Changeset.new('spec/fixtures/empty.git', 'master')
      expect(changeset.validate(report_path)).to eq(:no_changes)
    end

    it 'returns :stale_coverage if coverage report is older than last file change' do
      changeset = Undercover::Changeset.new('spec/fixtures/test.git', 'master')

      Timecop.freeze do
        file_paths = changeset.file_paths.map { |p| "spec/fixtures/#{p}" }
        FileUtils.touch(file_paths, mtime: Time.now)
        FileUtils.touch(report_path, mtime: Time.now - 60)
      end

      expect(changeset.validate(report_path)).to eq(:stale_coverage)
    end

    it 'returns nil with no validation errors' do
      changeset = Undercover::Changeset.new('spec/fixtures/test.git', 'master')
      FileUtils.touch(report_path, mtime: Time.now)

      expect(changeset.validate(report_path)).to be_nil
    end
  end
end
