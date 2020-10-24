# frozen_string_literal: true

module BaconModule
  def self.foo
    puts 'Bacon.foo'
  end

  def bar
    puts 'Bacon#bar'
  end

  def baz
    puts "I'm covered!"
  end

  def branch_missed
    @val.nil? ? "hit" : "miss"
  end
end

def lonely_method
  puts "I'm lonely!"
end
