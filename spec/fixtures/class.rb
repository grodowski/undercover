# frozen_string_literal: true

class BaconClass
  def self.bar
    puts "BaconClass.bar\x87"
  end

  def foo
    puts 'BaconClass#foo'
  end

  class BaconChildClass
    def foo_child
      puts 'BaconClass::BaconChildClass#foo'
    end
  end
  private_constant :BaconChildClass
end
