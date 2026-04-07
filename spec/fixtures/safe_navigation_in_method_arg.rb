def log_exception(*args)
  args.size
end

def process_input(input, something: nil)
  return unless input.nil?

  log_exception(
    999,
    something&.id
  )
end
