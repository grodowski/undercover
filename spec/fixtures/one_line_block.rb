# frozen_string_literal: true
class BaconClass
  # types of bacon
  BACON_TYPES = %w[peameal back bacon].freeze

  def favorite
    BACON_TYPES.select{ |type| type == 'back bacon'} 
  end
end
