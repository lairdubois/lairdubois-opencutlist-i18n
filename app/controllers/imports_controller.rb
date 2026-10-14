# Brings the texts of a language's yml into the tool : preview what it would add or change, then write the admin's
# picks, as the translator they choose. The uploaded file waits in tmp/imports between the two.
class ImportsController < ApplicationController
  before_action :require_admin

  def new
    @languages = Language.targets
  end

  def preview
    file = params.require(:file)
    return redirect_to new_import_path, alert: t(".too_big") if file.size > TranslationFileImport::MAX_BYTES

    text = file.read.force_encoding("UTF-8").delete_prefix("﻿")
    return redirect_to new_import_path, alert: t(".not_utf8") unless text.valid_encoding?

    @language = chosen_language(file.original_filename)
    return redirect_to new_import_path, alert: t(".no_language") unless @language

    @filename = File.basename(file.original_filename.to_s)
    @plan = TranslationFileImport.new(text, @language).plan
    return redirect_to new_import_path, alert: t(".empty") if @plan.unmatched.empty? && [@plan.added, @plan.changed, @plan.same, @plan.no_translate].all?(&:empty?) && @plan.skipped.empty?

    @token = SecureRandom.hex(8)
    FileUtils.mkdir_p(upload_dir)
    File.write(upload_path(@token), text)
    @authors = authors
  rescue Psych::SyntaxError, ArgumentError => e
    redirect_to new_import_path, alert: t(".invalid_yaml", error: e.message)
  end

  def apply
    path = upload_path(params.require(:token))
    return redirect_to new_import_path, alert: t(".expired") unless File.exist?(path)

    language = Language.targets.find_by!(code: params.require(:language))
    user = User.enabled.find(params.require(:user_id))
    written, stale = TranslationFileImport.new(File.read(path), language).apply(params.fetch(:rows, {}).to_unsafe_h, user)
    File.delete(path)
    flash = { notice: t(".applied", count: written, language: language.name) }
    flash = { alert: "#{flash[:notice]} #{t('.stale', count: stale)}" } if stale.positive?
    redirect_to new_import_path, flash
  end

  private

  # The language picked, else the one the file name gives (de.yml, opencutlist-de.yml)
  def chosen_language(filename)
    languages = Language.targets.index_by(&:code)
    return languages[params[:language]] if params[:language].present?

    File.basename(filename.to_s, ".*").downcase.split(/[^a-z]+/).reverse_each.lazy.filter_map { |part| languages[part] }.first
  end

  # Who the revisions go to : the importing admin, or a member of the language
  def authors
    members = User.enabled.where(id: @language.memberships.select(:user_id)).where.not(id: current_user.id).order(:name)
    [current_user, *members]
  end

  def upload_dir
    Rails.root.join("tmp", "imports")
  end

  def upload_path(token)
    upload_dir.join("#{token.to_s.gsub(/[^0-9a-f]/, '')}.yml")
  end
end
