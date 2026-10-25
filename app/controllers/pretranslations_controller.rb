# State of the suggestions (written by Claude Code through the API), per target language
class PretranslationsController < ApplicationController
  before_action :require_admin

  def index
    @languages = Language.targets.to_a
    @rows = @languages.to_h do |language|
      pretranslator = Pretranslator.new(language)
      pending = pretranslator.pending
      suggestions = Suggestion.where(language: language)
      [language, {
        pending: pending.count,
        not_translated: pending.where.not(id: Translation.where(language: language).select(:unit_id)).count,
        todo: pretranslator.todo.count,
        # Current suggestions of the strings still to do, per origin
        origins: suggestions.current.where(unit_id: pending.select(:id)).group(:origin).count,
        stale: suggestions.joins(:unit).where("suggestions.source_hash IS NULL OR suggestions.source_hash <> units.source_hash").count,
        last_at: suggestions.maximum(:created_at),
        issues: Issue.still_open.where(language: language).count
      }]
    end
    @origins = @rows.values.flat_map { |r| r[:origins].keys }.uniq.sort
    sort_rows
  end

  # Includes (or not) the language's @no-translate keys in its pre-translation
  def no_translate
    language = Language.targets.find_by!(code: params[:lang])
    language.update!(pretranslate_no_translate: params[:enabled] == "1")
    redirect_to pretranslations_path(sort: params[:sort], dir: params[:dir])
  end

  private

  # Columns sortable through `sort` (an origin's as "origin:<name>") ; counts start descending, the language ascending
  SORTS = %w[language pending coverage todo stale last issues].freeze

  def sort_rows
    columns = SORTS + @origins.map { |origin| "origin:#{origin}" }
    @sort = columns.include?(params[:sort]) ? params[:sort] : "language"
    @dir = %w[asc desc].include?(params[:dir]) ? params[:dir] : default_dir(@sort)
    sign = @dir == "desc" ? -1 : 1
    # Ties stay by language name, whatever the direction
    @rows = @rows.sort { |(a, ra), (b, rb)| (sign * (sort_value(a, ra) <=> sort_value(b, rb))).nonzero? || SqliteFold.fold(a.name) <=> SqliteFold.fold(b.name) }.to_h
  end

  def default_dir(sort) = sort == "language" ? "asc" : "desc"
  helper_method :default_dir

  def sort_value(language, r)
    case @sort
    when "language" then SqliteFold.fold(language.name)
    when "coverage" then r[:pending].zero? ? 0 : (r[:pending] - r[:todo]).fdiv(r[:pending])
    when "last" then r[:last_at]&.to_f || 0
    when /\Aorigin:(.+)\z/ then r[:origins].fetch($1, 0)
    else r[@sort.to_sym]
    end
  end
end
