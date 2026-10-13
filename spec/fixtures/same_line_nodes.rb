# frozen_string_literal: true

class SameLine
  def pick = %w[a b].select { |type| type == 'a' }
end
