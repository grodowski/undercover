class MethodCoverage
  def called_one_liner = :called

  def never_called_one_liner = :never

  def never_called(
    arg
  )
    # explains the body
    arg.to_s
  end

  def called_with_literal_body
    nil
  end

  def ignored_one_liner = :ignored # simplecov:disable
end
