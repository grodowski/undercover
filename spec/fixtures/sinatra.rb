require 'sinatra'
get '/dummy_path' do
  "This line is not covered"
end

def foobar
  puts "bar"
end
