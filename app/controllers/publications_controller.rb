# Publishing the translations to the OCL repo as a pull request, once the admin checked a preview of the changes
class PublicationsController < ApplicationController
  before_action :require_admin

  def index
    @publications = Publication.includes(:user).order(id: :desc).limit(20)
    @auth = GithubAuth.new(user: current_user)
    @oauth = GithubOauth.new
    @can_push = OclRepo.new(auth: @auth).can_push?
  end

  def preview
    @result = Publisher.new(current_user).preview
    return if handled_status?

    @can_push = OclRepo.new(auth: GithubAuth.new(user: current_user)).can_push?
    render :preview
  rescue OclRepo::Error => e
    redirect_to publications_path, alert: t(".failed", error: e.message)
  end

  def create
    @result = Publisher.new(current_user).call(digest: params.require(:digest))
    render :show unless handled_status?
  rescue OclRepo::Error => e
    redirect_to publications_path, alert: t(".failed", error: e.message)
  end

  private

  def handled_status?
    case @result.status
    when :needs_sync then redirect_to new_sync_path, alert: t("publications.needs_sync")
    when :unchanged then redirect_to publications_path, notice: t("publications.unchanged")
    end
    performed?
  end
end
