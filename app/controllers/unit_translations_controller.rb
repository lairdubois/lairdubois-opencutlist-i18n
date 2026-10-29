# A language's editor on a key's page, where admins correct every language (translations/_editor, unit_page) :
# reloaded to drop the edits (edit), saved (update)
class UnitTranslationsController < ApplicationController
  include TranslationEditorData

  helper_method :ref_url

  before_action :require_admin
  before_action :set_translation

  # The saved text back in the editor ("Annuler")
  def edit
    render partial: "translations/editor", locals: editor_locals
  end

  # Saved alone, the text keeps its status ; approved, it is checked against the current fr. The editor comes back
  # with the key page's language status, counts and history following
  def update
    operations = TranslationOperations.new(current_user)
    if params[:reviewed] == "1"
      operations.save(@unit, @language, params[:text], reviewed: true)
    else
      operations.correct(@unit, @language, params[:text])
    end
    translations = @unit.translations_by_language
    # Before turbo_stream : its view context copies the instance variables (@refs) when first built
    locals = editor_locals.merge(saved: true)
    render turbo_stream: [
      turbo_stream.replace(helpers.dom_id(@unit, @language.code), partial: "translations/editor", locals: locals),
      turbo_stream.replace("unit_status_#{@unit.id}_#{@language.code}", partial: "units/language_status",
                                                                         locals: { unit: @unit, language: @language, translation: translations[@language] }),
      turbo_stream.replace("unit_status_counts_#{@unit.id}", partial: "units/status_counts",
                                                             locals: { unit: @unit, languages: Language.targets, translations: translations }),
      turbo_stream.replace("unit_history_count_#{@unit.id}", partial: "units/history_count", locals: { unit: @unit, count: @unit.revisions.count }),
      turbo_stream.replace("unit_history", partial: "units/history_frame", locals: { unit: @unit })
    ]
  end

  private

  # A $t() key, alone in the keys list (as on the key's page)
  def ref_url(ref)
    units_path(at: ref.index)
  end

  # Copied as is into every language : no editor
  def set_translation
    @unit = Unit.find(params[:unit_id])
    return head :unprocessable_content if @unit.copied

    @language = Language.targets.find_by!(code: params[:lang])
    en = Language.find_by(code: "en")
    @en = en if en && en != @language
  end

  def editor_locals
    @refs = Unit.refs([@unit])
    { unit: @unit, language: @language, data: preload_language(@language, [@unit]), unit_page: true }
  end
end
