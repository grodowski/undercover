class FooLib
    def initialize(name)
        @name = name
    end

    def greet
        "Hello, #{@name}!"
    end

    def greet_with_time(time_of_day)
        if time_of_day == "morning"
            "Good morning, #{@name}!"
        else
            "Hello, #{@name}!"
        end
    end

    def self.version
        "1.0.0"
    end
end