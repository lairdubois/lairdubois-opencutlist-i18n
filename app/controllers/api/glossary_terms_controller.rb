# The whole glossary, filled by Claude Code (Api::BaseController, no language) : GET every active term with each
# target language's entry, POST creates fr terms or changes some of their fields (definitions are written in English).
# Every change goes through GlossaryOperations, signed ORIGIN in the terms' history.
class Api::GlossaryTermsController < Api::BaseController
  skip_before_action :set_language

  def index
    languages = Language.targets.order(:code).to_a
    codes = languages.to_h { |language| [language.id, language.code] }
    terms = GlossaryTerm.active.includes(:entries).sort_by { |term| SqliteFold.fold(term.term) }
    render json: {
      languages: codes.values,
      terms: terms.map do |term|
        entries = term.entries.select { |entry| codes.key?(entry.language_id) }
        { id: term.id, fr: term.term, fr_variants: GlossaryTerm.split_list(term.variants).presence, definition: term.definition,
          keep_as_is: (true if term.no_translate),
          entries: entries.to_h { |entry| [codes[entry.language_id], describe(entry)] }.sort.to_h }.compact
      end
    }
  end

  # { terms: [{ id, term, variants, definition, no_translate }] } : without id, a new term (one whose fr is already a
  # form of an active term is skipped with that term's id) ; with id, the fields given only. variants : a string
  # ("a, b") or an array.
  def create
    items = batch(:terms) or return

    forms = GlossaryTerm.form_index
    operations = glossary_operations
    result = { created: [], updated: [], unchanged: [], skipped: [] }
    items.each_with_index do |item, index|
      f = item.permit(:id, :term, :variants, :definition, :no_translate, variants: [])
      attributes = f.to_h.slice(*GlossaryTerm::FIELDS)
      attributes["variants"] = Array(attributes["variants"]).join(", ") if attributes.key?("variants")
      if f[:id].present?
        term = GlossaryTerm.find_by(id: f[:id])
        next result[:skipped] << { index: index, reason: "unknown id" } unless term
        next result[:skipped] << { index: index, id: term.id, reason: "archived" } if term.archived?

        operations.update_term(term, attributes)
        if term.errors.any?
          result[:skipped] << { index: index, id: term.id, reason: term.errors.full_messages.to_sentence }
        else
          result[term.previous_changes.slice(*GlossaryTerm::FIELDS).any? ? :updated : :unchanged] << term.id
        end
      else
        existing = forms[SqliteFold.fold(f[:term].to_s.squish)]
        next result[:skipped] << { index: index, id: existing.id, reason: "exists" } if existing

        term = operations.create_term(attributes)
        next result[:skipped] << { index: index, reason: term.errors.full_messages.to_sentence } unless term.persisted?

        term.forms.each { |form| forms[SqliteFold.fold(form)] ||= term }
        result[:created] << { id: term.id, fr: term.term }
      end
    end
    render json: result
  end

  private

  def describe(entry)
    { translation: entry.term, variants: GlossaryTerm.split_list(entry.variants).presence, avoid: entry.avoided.presence,
      note: entry.note }.compact
  end
end
