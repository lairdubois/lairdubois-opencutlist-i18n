class Language < ApplicationRecord
  SOURCE_CODE = "fr".freeze

  has_many :translations, dependent: :destroy
  has_many :memberships, dependent: :destroy

  validates :code, presence: true, uniqueness: true

  default_scope { order(:position, :code) }
  scope :targets, -> { where.not(code: SOURCE_CODE) }

  # Progress of each language over the translators' keys (the @no-translate ones left out) :
  # { language => { translated:, outdated:, reviewed:, total: } }
  def self.stats(languages)
    total = Unit.active.translatable.count
    counts = Translation.joins(:unit).merge(Unit.active.translatable).where(language: languages).group(:language_id)
                        .pluck(:language_id, Arel.sql("COUNT(*)"),
                               Arel.sql("SUM(translations.source_hash <> units.source_hash)"),
                               Arel.sql("SUM(translations.status = 1)"))
                        .to_h { |id, n, outdated, reviewed| [id, { translated: n, outdated: outdated.to_i, reviewed: reviewed.to_i }] }
    languages.to_h { |l| [l, counts.fetch(l.id, { translated: 0, outdated: 0, reviewed: 0 }).merge(total: total)] }
  end

  def source?
    code == SOURCE_CODE
  end
end
