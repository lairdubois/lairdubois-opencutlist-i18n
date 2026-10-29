# What the translator's editor (translations/_editor) needs, shared by the translator's list and the key page
module TranslationEditorData
  extend ActiveSupport::Concern

  private

  # What one language's editor needs (@en : the reference language, nil when it is the edited one). glossary : one
  # already loaded with both languages, shared by several editors (each costs its patterns)
  def preload_language(language, units, glossary: nil)
    ids = units.map(&:id)
    texts = units.map(&:source_text)
    translations = Translation.where(unit_id: ids, language: language).includes(:unit).index_by(&:unit_id)
    {
      translations: translations,
      # The terms expected in the language : the editor's warnings, the references' tooltips (en's found by its entries)
      glossary: glossary || Glossary.new([language, @en].compact),
      # Units with an open issue of any kind : to review, no approval until closed
      contested: Translation.preload_contested(translations, language, ids),
      machine: Suggestion.current.where(unit_id: ids, language: language).pluck(:unit_id, :text).to_h,
      comment_counts: Comment.visible_in(language).visible_to(current_user).where(unit_id: ids).group(:unit_id).count,
      open_questions: Comment.open_questions.visible_in(language).where(unit_id: ids).group(:unit_id).count,
      open_admin_notes: Comment.open_admin_notes.visible_in(language).visible_to(current_user).where(unit_id: ids).group(:unit_id).count,
      issues: Issue.still_open.where(language: language, unit_id: ids).group(:unit_id).count,
      # Same fr text already translated elsewhere in this language
      suggestions: Translation.joins(:unit).merge(Unit.active).where(language: language, units: { source_text: texts })
                              .where.not(unit_id: ids).pluck("units.source_text", "translations.text")
                              .group_by(&:first).transform_values { |v| v.map(&:last).uniq.first(3) }
    }
  end
end
