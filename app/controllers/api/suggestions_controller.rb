# Suggestions written from outside (Api::BaseController) :
# GET todo lists a language's strings to do with their context, GET search finds how a term is already translated,
# POST stores suggestions, never translations
class Api::SuggestionsController < Api::BaseController
  ORIGIN = "claude-code".freeze

  # The language's units not translated or outdated, without a current suggestion, in the keys' order
  def todo
    pretranslator = Pretranslator.new(@language)
    scope = pretranslator.todo
    units = scope.limit(limit(50)).to_a
    render json: {
      language: { code: @language.code, name: @language.name },
      total: scope.count,
      rules: Pretranslator::SYSTEM,
      examples: pretranslator.examples(units),
      glossary: pretranslator.glossary(units),
      strings: pretranslator.strings(units)
    }
  end

  # The language's translations whose fr or text holds q (case and accents aside), the reviewed and up to date first,
  # short ones first, copies of the fr last : the vocabulary already in use, read from here rather than from a copy
  # of the database
  def search
    q = params[:q].to_s.strip
    return render(json: { error: "q is too short" }, status: :unprocessable_content) if q.length < 2

    like = "%#{Unit.sanitize_sql_like(SqliteFold.fold(q))}%"
    rows = Translation.joins(:unit).merge(Unit.active).where(language: @language)
                      .where("fold(units.source_text) LIKE :like ESCAPE '\\' OR fold(translations.text) LIKE :like ESCAPE '\\'", like: like)
                      .reorder(Arel.sql("translations.text = units.source_text"), "translations.status DESC",
                               Arel.sql("translations.source_hash = units.source_hash DESC"), Arel.sql("LENGTH(units.source_text)"))
                      .limit(limit(30))
                      .pluck("units.key", "units.source_text", "translations.text", "translations.status", Arel.sql("translations.source_hash <> units.source_hash"))
    render json: {
      results: rows.map do |key, fr, text, status, outdated|
        { key: key, fr: fr, text: text, status: status, outdated: outdated == 1, same_as_fr: text == fr }
      end
    }
  end

  # { suggestions: [{ id:, source_hash:, text: }] } : a unit translated (up to date) or whose fr moved since is skipped ;
  # one still to do replaces its suggestion, even a current one (a correction)
  def create
    items = params.require(:suggestions).map { |s| s.permit(:id, :source_hash, :text) }
    pending = Pretranslator.new(@language).pending.where(id: items.map { |s| s[:id] }).index_by(&:id)
    written, skipped = items.partition do |s|
      unit = pending[s[:id].to_i]
      unit && Suggestion.store!(unit, @language, s[:text].to_s, origin: ORIGIN, source_hash: s[:source_hash])
    end
    render json: { written: written.size, skipped: skipped.map { |s| s[:id].to_i } }
  end
end
