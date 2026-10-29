# A language's glossary (Api::BaseController) : GET the fr terms (id), their definition and the language's expected
# term, for the consistency reviews (the pre-translation gets the terms of its strings with them,
# Api::SuggestionsController#todo) ; POST fills the language's entries (Claude Code), through GlossaryOperations,
# signed ORIGIN in the terms' history
class Api::GlossaryController < Api::BaseController
  def index
    glossary = Glossary.new([@language])
    render json: {
      language: { code: @language.code, name: @language.name },
      terms: glossary.terms.map { |term| { id: term.id, **glossary.describe(term, @language) } }
    }
  end

  # { entries: [{ id (the term's) or fr (one of its forms), translation, variants, avoid, note, replace }] } : the
  # fields given only (variants, avoid : a string "a, b" or an array ; "" clears one). A field already set to another
  # value isn't overwritten without replace: true (the item is skipped, its fields named) ; terms kept as is and
  # archived ones are skipped.
  def create
    items = batch(:entries) or return

    forms = GlossaryTerm.form_index
    operations = glossary_operations
    result = { saved: [], unchanged: [], skipped: [] }
    items.each_with_index do |item, index|
      f = item.permit(:id, :fr, :translation, :variants, :avoid, :note, :replace, variants: [], avoid: [])
      term = f[:id].present? ? GlossaryTerm.find_by(id: f[:id]) : forms[SqliteFold.fold(f[:fr].to_s.squish)]
      next result[:skipped] << { index: index, reason: "unknown term" } unless term
      next result[:skipped] << { index: index, id: term.id, reason: "archived" } if term.archived?
      next result[:skipped] << { index: index, id: term.id, reason: "kept as is" } if term.no_translate

      attributes = entry_attributes(f)
      entry = term.entries.find_or_initialize_by(language: @language)
      before = entry.attributes.slice(*GlossaryEntry::FIELDS)
      entry.assign_attributes(attributes)
      conflicts = attributes.keys.select { |field| before[field].present? && before[field] != entry[field] }
      if conflicts.any? && !ActiveModel::Type::Boolean.new.cast(f[:replace])
        next result[:skipped] << { index: index, id: term.id, reason: "already set", fields: conflicts.map { |field| field == "term" ? "translation" : field } }
      end

      entry = operations.save_entry(term, @language, attributes)
      if entry.errors.any?
        result[:skipped] << { index: index, id: term.id, reason: entry.errors.full_messages.to_sentence }
      else
        result[entry.destroyed? || entry.previous_changes.slice(*GlossaryEntry::FIELDS).any? ? :saved : :unchanged] << term.id
      end
    end
    render json: result
  end

  private

  def entry_attributes(f)
    { "term" => (f[:translation] if f.key?(:translation)), "variants" => (Array(f[:variants]).join(", ") if f.key?(:variants)),
      "avoid" => (Array(f[:avoid]).join(", ") if f.key?(:avoid)), "note" => (f[:note] if f.key?(:note)) }
      .select { |field, _| f.key?(field == "term" ? :translation : field) }
  end
end
