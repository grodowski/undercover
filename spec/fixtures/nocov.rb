# :nocov:
def method_no_coverage
  puts 'ignore me'
end
# :nocov:

def method_with_cov
  puts 'do not ignore'
  puts 'please'
end
