# frozen_string_literal: true

require 'spec_helper'

# These tests use the the fixture repo test.git
# use `git --git-dir=test.git <command>` to inspect
# or modify it.
describe Undercover::Changeset do
  it 'diffs index and staging area against HEAD' do
    changeset = Undercover::Changeset.new(
      'spec/fixtures/test.git'
    ).update

    expect(changeset.files.keys).to match_array(
      %w[file_one file_two staged_file class.rb module.rb]
    )
    expect(changeset.files['file_two']).to eq([7, 10, 11])
  end

  it 'has all the changes agains base with compare_base arg' do
    changeset = Undercover::Changeset.new(
      'spec/fixtures/test.git',
      'master'
    ).update

    expect(changeset.file_paths).to match_array(
      %w[file_one file_three file_two staged_file class.rb module.rb]
    )
    expect(changeset.files['file_two']).to eq([7, 10, 11])
    expect(changeset.files['file_three']).to eq([1, 2, 3, 4, 5, 6])
  end

  it 'has a last_modified when changes are present' do
    changeset = Undercover::Changeset.new(
      'spec/fixtures/test.git',
      'master'
    ).update

    Timecop.freeze do
      file_paths = changeset.file_paths.map { |p| "spec/fixtures/#{p}" }
      FileUtils.touch(file_paths, mtime: Time.now)
      expect(changeset.last_modified.to_i).to eq(Time.now.to_i)
    end
  end

  it 'has a default last_modified with no changes' do
    changeset = Undercover::Changeset.new('spec/fixtures/test.git', 'master')
    expect(changeset.last_modified).to eq(Undercover::Changeset::T_ZERO)
  end

  describe 'validate' do
    let(:report_path) { 'spec/fixtures/sample.lcov' }

    it 'returns :no_changes with empty files' do
      changeset = Undercover::Changeset.new('spec/fixtures/test.git', 'master') # no update
      expect(changeset.validate(report_path)).to eq(:no_changes)
    end

    it 'returns :stale_coverage if coverage report is older than last file change' do
      changeset = Undercover::Changeset.new('spec/fixtures/test.git', 'master').update

      Timecop.freeze do
        file_paths = changeset.file_paths.map { |p| "spec/fixtures/#{p}" }
        FileUtils.touch(file_paths, mtime: Time.now)
        FileUtils.touch(report_path, mtime: Time.now - 60)
      end

      expect(changeset.validate(report_path)).to eq(:stale_coverage)
    end

    it 'returns nil with no validation errors' do
      changeset = Undercover::Changeset.new('spec/fixtures/test.git', 'master').update
      FileUtils.touch(report_path, mtime: Time.now)

      expect(changeset.validate(report_path)).to be_nil
    end
  end
end
