class Translation < ApplicationRecord
  belongs_to :unit
  belongs_to :language

  enum :status, { translated: 0, approved: 1 }

  validates :text, presence: true
  validates :language_id, uniqueness: { scope: :unit_id }

  # Set by the lists from one query (Issue.contested_unit_ids), else asked
  attr_writer :contested

  # SQL condition on a translations row joined to its unit : to review (outdated or contested), never approved
  def self.to_review_sql
    "(translations.source_hash <> units.source_hash OR #{Issue.contested_sql})"
  end

  # Marks each translation of the hash (unit id => translation) contested or not, in one query ;
  # returns the contested ones among unit_ids (untranslated units included : their approval waits too)
  def self.preload_contested(translations, language, unit_ids = translations.keys)
    ids = Issue.contested_unit_ids(language, unit_ids)
    translations.each { |unit_id, t| t.contested = ids.include?(unit_id) }
    ids
  end

  # The fr text changed since this translation was written (and the change was not declared minor)
  def outdated?
    source_hash.present? && source_hash != unit.source_hash
  end

  # Questioned by an open issue (any kind) : to review until it is closed
  def contested?
    @contested = Issue.contesting.exists?(unit_id: unit_id, language_id: language_id) if @contested.nil?
    @contested
  end

  # Outdated or contested : the "to review" status, which takes precedence over approved
  def to_review?
    outdated? || contested?
  end
end
