# frozen_string_literal: true
class TestTwoPatches
  def method_1
    if false
      puts 'not tested'
      puts 'not tested'
      puts 'not tested'
    end
  end

  def method_2
    render json: @review.job.video_metadata
  end

  def method_3
    1.upto(10) do |num|
      puts("#{num}say wow!")
    end

    if false
      puts "warn warn warn"
    end
  end

  def method_4
    puts 'tested!'
  end
end
