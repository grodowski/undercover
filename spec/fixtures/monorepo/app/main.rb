require_relative 'foo_lib'

def work
    foo = FooLib.new("World")
    puts foo.greet
    puts "FooLib version: #{FooLib.version}"
end