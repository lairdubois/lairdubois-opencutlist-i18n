# A machine-proposed translation, waiting for a human to accept or correct it
class Suggestion < ApplicationRecord
  belongs_to :unit
  belongs_to :language

  validates :text, presence: true

  # Computed on the unit's current fr text (a minor edit moves the hash along, like translations')
  scope :current, -> { joins(:unit).where("suggestions.source_hash = units.source_hash") }

  # Replaces the unit's suggestion in this language ; false when the text is blank or the fr moved since
  # the suggestion was computed on it (source_hash)
  def self.store!(unit, language, text, origin:, source_hash:)
    return false if text.blank? || source_hash != unit.source_hash

    transaction do
      where(unit: unit, language: language).delete_all
      create!(unit: unit, language: language, text: text, origin: origin, source_hash: source_hash)
    end
    true
  end
end
