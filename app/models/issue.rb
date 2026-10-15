# A point needing a human look in one language : a term used inconsistently, a text translating another key,
# a doubtful meaning, a suggestion to reread. Raised from outside (Claude Code through the API, origin), about a key
# or the whole language (unit nil), listed on the language's issues page until someone closes it.
# text : the translation (else the current suggestion) as it was when raised, to tell whether it changed since.
class Issue < ApplicationRecord
  KINDS = %w[terminology misaligned meaning review other].freeze

  belongs_to :language
  belongs_to :unit, optional: true
  belongs_to :closed_by, class_name: "User", optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :body, presence: true, length: { maximum: 5000 }

  scope :still_open, -> { where(closed_at: nil) }
  scope :closed, -> { where.not(closed_at: nil) }
  # About a key, whatever its kind : while one is open, the key's translation is to review and can't be approved
  scope :contesting, -> { still_open.where.not(unit_id: nil) }
  # In the translators' work : the whole language's, or about an active translatable key (not archived, no @no-translate)
  scope :in_work, -> { left_joins(:unit).where(unit_id: nil).or(left_joins(:unit).where(units: { archived_at: nil, translatable: true })) }

  # The ones a user is shown : all of them for an admin, else those in the translators' work (the others come back
  # with their key)
  def self.visible_to(user)
    user.admin? ? all : in_work
  end

  # SQL condition on a translations row : an open issue about it
  def self.contested_sql
    "EXISTS (SELECT 1 FROM issues WHERE issues.unit_id = translations.unit_id AND issues.language_id = translations.language_id " \
      "AND issues.closed_at IS NULL)"
  end

  # The unit ids of these units with an open issue in the language
  def self.contested_unit_ids(language, unit_ids)
    contesting.where(language: language, unit_id: unit_ids).distinct.pluck(:unit_id).to_set
  end

  def closed?
    closed_at.present?
  end

  # Why its key is out of the translators' work (archived, no_translate), nil when it isn't
  def out_of_work
    return unless unit

    if unit.archived? then :archived
    elsif !unit.translatable then :no_translate
    end
  end
end
