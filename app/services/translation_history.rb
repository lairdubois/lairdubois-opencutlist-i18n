# A unit's history, newest first : the revisions of one language (Transifex imports included) between
# the unit's own events (fr source changes, renames), for the translator's editor ; every revision
# without a language, for the key page
class TranslationHistory
  # Revisions of the language
  TEXT_KINDS = %w[import translate review].freeze
  # Revisions of the unit, without a language
  SOURCE_KINDS = %w[import create source_minor source_major].freeze
  UNIT_KINDS = (SOURCE_KINDS + %w[rename archive restore]).freeze

  # source_then : the fr text when the revision was made, when a major fr change came after it
  Entry = Struct.new(:revision, :diff, :source_then, :copyable, keyword_init: true) do
    def text? = revision.language_id.present?
    def deleted? = text? && revision.new_value.nil?

    # The translation's status the revision produced (ApplicationHelper::STATUS_DOTS keys) ; a major
    # fr change makes translations outdated. Transifex imports don't record whether they were reviewed.
    def status
      if text?
        if deleted? then "untranslated"
        elsif revision.kind == "review" then "reviewed"
        else "unreviewed"
        end
      elsif revision.kind == "source_major"
        "outdated"
      end
    end
  end

  def initialize(unit, language = nil)
    @unit = unit
    @language = language
  end

  # copyable : a text of the language other than its current one, to refill the editor with
  def entries
    revisions = if @language
                  @unit.revisions.where(language: @language, kind: TEXT_KINDS)
                       .or(@unit.revisions.where(language: nil, kind: UNIT_KINDS)).to_a
                else
                  @unit.revisions.includes(:language).to_a
                end
    last_major = revisions.rindex { |r| r.language_id.nil? && r.kind == "source_major" }
    current = @unit.translations.find_by(language: @language)&.text if @language
    source = nil
    revisions.each_with_index.map do |r, i|
      if r.language_id.nil?
        source = r.new_value if SOURCE_KINDS.include?(r.kind)
        Entry.new(revision: r, diff: (WordDiff.call(r.old_value, r.new_value) if r.old_value && %w[source_minor source_major note].include?(r.kind)))
      else
        Entry.new(revision: r, diff: text_diff(r),
                  source_then: (source if last_major && i < last_major && source != @unit.source_text),
                  copyable: @language.present? && r.new_value.present? && r.new_value != current)
      end
    end.reverse
  end

  private

  # Nothing to compare for a first text or an approval leaving it as is
  def text_diff(revision)
    return if revision.old_value.nil? || revision.new_value.nil? || revision.old_value == revision.new_value

    WordDiff.call(revision.old_value, revision.new_value)
  end
end
