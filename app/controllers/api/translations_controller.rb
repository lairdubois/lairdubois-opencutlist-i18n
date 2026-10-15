# A language's texts for a consistency review from outside (Api::BaseController) : every translator's key in the
# keys' order, paged (offset, limit), with its fr, en, translation (status, outdated) and current suggestion
class Api::TranslationsController < Api::BaseController
  MAX_LIMIT = 500

  def index
    scope = Unit.active.translatable.reorder(:position, :id)
    offset = params[:offset].to_i.clamp(0, nil)
    units = scope.offset(offset).limit(limit(200)).to_a
    ids = units.map(&:id)
    translations = Translation.where(language: @language, unit_id: ids).index_by(&:unit_id)
    suggestions = Suggestion.current.where(unit_id: ids, language: @language).pluck(:unit_id, :text).to_h
    by_id = units.index_by(&:id)
    render json: {
      language: { code: @language.code, name: @language.name },
      total: scope.count,
      offset: offset,
      strings: Pretranslator.new(@language, client: nil).strings(units).map do |s|
        t = translations[s[:id]]
        s.except(:source_hash).merge(text: t&.text, status: t&.status, outdated: (t.source_hash != by_id[s[:id]].source_hash if t),
                                     suggestion: suggestions[s[:id]]).compact
      end
    }
  end
end
