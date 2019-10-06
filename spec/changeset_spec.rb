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

    expect(changeset.files.keys.sort).to eq(%w[file_one file_two staged_file])
    expect(changeset.files['file_two']).to eq([7, 10, 11])
  end

  it 'has all the changes agains base with compare_base arg' do
    changeset = Undercover::Changeset.new(
      'spec/fixtures/test.git',
      'master'
    ).update

    expect(changeset.file_paths).to eq(
      %w[file_one file_three file_two staged_file]
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
end
