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

    expect(changeset.files.keys.sort).to eq(
      %w[file_one file_three file_two staged_file]
    )
    expect(changeset.files['file_two']).to eq([7, 10, 11])
    expect(changeset.files['file_three']).to eq([1, 2, 3, 4, 5, 6])
  end
end
