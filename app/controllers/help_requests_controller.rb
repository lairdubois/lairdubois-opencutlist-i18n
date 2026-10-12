class HelpRequestsController < ApplicationController
  before_action :require_admin, except: :create
  rate_limit to: 5, within: 1.hour, by: -> { current_user.id }, only: :create,
             with: -> { redirect_to help_path, alert: t("sessions.rate_limited") }

  # Open ones first, the newest on top
  def index
    @help_requests = HelpRequest.includes(:user, :language).order(Arel.sql("resolved_at IS NOT NULL"), created_at: :desc).limit(200)
  end

  # Kept even when e-mails are off : the admins see it here and on their help link's badge
  def create
    page = HelpRequest.safe_page(params[:page])
    help_request = HelpRequest.new(user: current_user, body: params[:body].to_s.strip, page: page, language: page_language(page))
    return redirect_to(help_path(from: page), alert: t(".empty")) unless help_request.save

    help_request.recipients.each { |admin| HelpMailer.requested(help_request, admin).deliver_later }
    redirect_to help_path(from: page), notice: t(".sent")
  end

  def resolve
    HelpRequest.find(params[:id]).update!(resolved_at: params[:reopen] ? nil : Time.current)
    redirect_to help_requests_path
  end

  private

  # The language of a translator's list the user came from
  def page_language(page)
    code = page&.match(%r{\A/translate/([^/?#]+)})&.[](1)
    Language.find_by(code: code) if code
  end
end
