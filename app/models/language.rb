class Language < ApplicationRecord
  SOURCE_CODE = "fr".freeze

  has_many :translations, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :issues, dependent: :destroy
  has_many :glossary_entries, dependent: :destroy
  has_many :glossary_revisions, dependent: :destroy

  validates :code, presence: true, uniqueness: true

  default_scope { order(:position, :code) }
  scope :targets, -> { where.not(code: SOURCE_CODE) }

  # Progress of each language over the translators' keys (the @no-translate ones left out) :
  # { language => { translated:, outdated:, approved:, total: } }. outdated = to review (fr changed, or contested by
  # an open issue), never counted as approved
  def self.stats(languages)
    total = Unit.active.translatable.count
    to_review = Translation.to_review_sql
    counts = Translation.joins(:unit).merge(Unit.active.translatable).where(language: languages).group(:language_id)
                        .pluck(:language_id, Arel.sql("COUNT(*)"),
                               Arel.sql("SUM(#{to_review})"),
                               Arel.sql("SUM(translations.status = 1 AND NOT #{to_review})"))
                        .to_h { |id, n, outdated, approved| [id, { translated: n, outdated: outdated.to_i, approved: approved.to_i }] }
    languages.to_h { |l| [l, counts.fetch(l.id, { translated: 0, outdated: 0, approved: 0 }).merge(total: total)] }
  end

  def source?
    code == SOURCE_CODE
  end
end
