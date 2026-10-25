# Points needing a human look, raised from outside (Api::BaseController) after a consistency review of a language :
# GET lists them (to avoid raising one twice), POST raises new ones. Closed from the language's issues page.
class Api::IssuesController < Api::BaseController
  # state : open (default), closed or all
  def index
    scope = Issue.where(language: @language).includes(:unit).order(:id)
    scope = params[:state] == "all" ? scope : params[:state] == "closed" ? scope.closed : scope.still_open
    render json: {
      issues: scope.map do |issue|
        { id: issue.id, key: issue.unit&.key, unit_id: issue.unit_id, kind: issue.kind, body: issue.body, text: issue.text,
          closed: issue.closed?, created_at: issue.created_at }
      end
    }
  end

  # { issues: [{ key (or id, or neither : the whole language), kind, body, text }] } : text defaults to the
  # translation, else the current suggestion. One already raised (duplicate) is skipped, with the existing one's id,
  # and so is one about a key out of the translators' work.
  def create
    items = params.require(:issues).map { |issue| issue.permit(:id, :key, :kind, :body, :text) }
    units = Unit.active.where(id: items.filter_map { |f| f[:id].presence })
                .or(Unit.active.where(key: items.filter_map { |f| f[:key].presence })).to_a
    by_id = units.index_by(&:id)
    by_key = units.index_by(&:key)
    created = []
    skipped = []
    items.each_with_index do |f, i|
      named = f[:id].present? || f[:key].present?
      unit = f[:id].present? ? by_id[f[:id].to_i] : by_key[f[:key]]
      next skipped << { index: i, reason: "unknown key" } if named && unit.nil?
      # Out of the translators' work (@no-translate, copied) : nobody would see it
      next skipped << { index: i, reason: "not translatable" } if unit && !unit.translatable

      issue = Issue.new(language: @language, unit: unit, kind: f[:kind], body: f[:body].to_s.strip,
                            text: f[:text].presence || snapshot(unit), origin: ORIGIN)
      if (existing = duplicate(issue))
        next skipped << { index: i, reason: existing.closed? ? "already resolved" : "already open", id: existing.id }
      end
      next skipped << { index: i, reason: issue.errors.full_messages.join(", ") } unless issue.save

      created << issue.id
    end
    render json: { created: created.size, ids: created, skipped: skipped }
  end

  private

  # The same point already raised, open or resolved (a resolved one was judged) : on a key, the same kind about the
  # same text, whatever the wording (a rerun on an unchanged translation raises nothing ; a changed one can be raised
  # again) ; on the whole language, or a key without any text, the same kind and body. The open one first.
  def duplicate(issue)
    scope = Issue.where(language: @language, unit: issue.unit, kind: issue.kind)
    scope = issue.unit && issue.text ? scope.where(text: issue.text) : scope.where(body: issue.body)
    scope.reorder(:closed_at, :id).first
  end

  def snapshot(unit)
    return unless unit

    Translation.find_by(unit: unit, language: @language)&.text || Suggestion.current.find_by(unit: unit, language: @language)&.text
  end
end
