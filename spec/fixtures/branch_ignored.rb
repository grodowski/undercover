def test_branch_ignored(arg)
  if arg == :arg1
    if ENV["FOO"] != "BAR"
      :sym1
    # :nocov:
    else
      :sym2
    end
    # :nocov:
  end
end
