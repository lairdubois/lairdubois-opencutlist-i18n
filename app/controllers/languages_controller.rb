# Home : every target language with its progress (the @no-translate keys left out), in three columns : work left
# (to translate or outdated), to approve, ready. The ones the user can't edit are greyed out, not linked, or left out
# with mine=1 (offered when the user can edit some but not all)
class LanguagesController < ApplicationController
  COLUMNS = { todo: [:outdated, :translating], to_approve: [:translated], ready: [:approved] }.freeze

  def index
    @languages = Language.targets.to_a
    @editable = current_user.editable_languages.pluck(:id).to_set
    @mine_filter = @editable.any? && @editable.size < @languages.size
    @mine = @mine_filter && params[:mine] == "1"
    @stats = Language.stats(@languages)
    @states = @languages.to_h { |l| [l, state(@stats[l])] }
    shown = @mine ? @languages.select { |l| @editable.include?(l.id) } : @languages
    @columns = COLUMNS.transform_values { |states| shown.select { |l| states.include?(@states[l]) } }
    # The most advanced first, ties in the usual order : work left on translated (then approved), to approve on approved
    @columns[:todo] = sort_by_progress(@columns[:todo], :translated, :approved)
    @columns[:to_approve] = sort_by_progress(@columns[:to_approve], :approved)
    # Ready : by name, case and accents aside
    @columns[:ready] = @columns[:ready].sort_by { |l| SqliteFold.fold(l.name) }
  end

  private

  def sort_by_progress(languages, *counts)
    languages.each_with_index.sort_by { |l, i| [*counts.map { |c| -@stats[l][c] }, i] }.map(&:first)
  end

  def state(s)
    if s[:outdated] > 0 then :outdated
    elsif s[:translated] < s[:total] then :translating
    elsif s[:approved] < s[:total] then :translated
    else :approved
    end
  end
end
