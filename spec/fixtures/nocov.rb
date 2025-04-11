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
  puts 'do not ignore'
  puts 'please'
end
