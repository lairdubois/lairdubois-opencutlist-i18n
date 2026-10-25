# What Claude Code needs to propose translations through the API (Api::SuggestionsController) : the units to do,
# the rules, examples and glossary. Results are stored as suggestions, never as translations : a translator accepts
# or corrects each one.
class Pretranslator
  SYSTEM = <<~PROMPT.freeze
    You translate the user interface of OpenCutList, a SketchUp extension for woodworkers
    (cutting lists, cutting diagrams, panel nesting, labels, cost and weight reports, cabinet building tools).
    The source language is French ; an English version is given as a reference when it exists.

    Rules :
    - Keep every {{ variable }}, $t(key) reference, HTML tag and markdown marker (**bold**, *italic*, [text](url)) exactly as in the source.
    - Keep line breaks : the translation has the same number of lines as the source.
    - Use the woodworking vocabulary a craftsman of the target language would use, and stay consistent with the existing translations given as examples.
    - Short UI labels stay short.
    - Follow the glossary given with the strings : each fr term (or one of its fr_variants) is translated by its
      translation (or one of its variants, as the grammar needs), never by a term to avoid ; a keep_as_is term stays as
      written. Its definitions tell the notions apart : two terms of different definitions never get the same word.
      A term without a translation is translated following its definition and note.
    Answer with one translation per requested id.
  PROMPT

  def initialize(language)
    @language = language
  end

  # The translators' units of this language not translated, or outdated (major fr change). With the language's
  # pretranslate_no_translate, the @no-translate ones too (never the copied ones : nothing to translate)
  def pending
    translations = Translation.where(language: @language).where("translations.unit_id = units.id AND translations.source_hash = units.source_hash")
    units = @language.pretranslate_no_translate? ? Unit.active.where(copied: false) : Unit.active.translatable
    units.where.not(translations.arel.exists)
  end

  # The pending ones without a current suggestion
  def todo
    current = Suggestion.where(language: @language).where("suggestions.unit_id = units.id AND suggestions.source_hash = units.source_hash")
    pending.where.not(current.arel.exists)
  end

  # What is given for each unit, the fr hash included (Suggestion.store! refuses a moved one)
  def strings(units)
    en = Language.find_by(code: "en")
    references = en && @language != en ? Translation.where(unit: units, language: en).pluck(:unit_id, :text).to_h : {}
    units.map { |u| { id: u.id, key: u.key, fr: u.source_text, en: references[u.id], note: u.note, source_hash: u.source_hash }.compact }
  end

  # The glossary terms found in the units' fr texts, with the language's expected terms (Glossary#describe)
  def glossary(units)
    Glossary.new([@language]).describe_in(units.map(&:source_text), @language)
  end

  # Reviewed (else any) translations of this language from the same branches, short ones first
  def examples(units)
    branches = units.map { |u| u.key.split(".").first(2).join(".") }.uniq
    scope = Translation.joins(:unit).merge(Unit.active).where(language: @language).where.not(unit_id: units.map(&:id))
    scope = scope.where(branches.map { "units.key LIKE ? ESCAPE '\\'" }.join(" OR "), *branches.map { |b| "#{Unit.sanitize_sql_like(b)}.%" })
    scope.reorder("translations.status DESC", Arel.sql("LENGTH(units.source_text)")).limit(40)
         .pluck("units.source_text", "translations.text").map { |fr, t| { fr: fr, translation: t } }
  end
end
