# :nocov:
def method_no_coverage
  puts 'ignore me'
  if @ivar
    method_with_cov
  else
    exit 1
  end
end
# :nocov:

def method_with_cov
  if @ivar
    uncovered_method
  else
    # :nocov:
    exit 1
    # :nocov:
  end
end
