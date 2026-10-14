# Offers to translate (VolunteerRequest) : the public form (new / create) and the admins' list
class VolunteersController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]
  before_action :require_admin, except: [:new, :create]
  before_action :redirect_logged_in, only: [:new, :create]
  before_action :set_volunteer_request, only: [:accept, :reject]
  # Per IP (behind NGINX : X-Forwarded-For from the local proxy)
  rate_limit to: 3, within: 1.hour, only: :create, with: -> { redirect_to new_session_path, alert: t("sessions.rate_limited") }

  HANDLED_SHOWN = 50

  # Pending ones first, then the last handled
  def index
    @pending = VolunteerRequest.pending.order(created_at: :desc).to_a
    @handled = VolunteerRequest.where.not(status: :pending).includes(:user, :handled_by)
                               .order(handled_at: :desc).limit(HANDLED_SHOWN).to_a
    @users = User.where(email: @pending.map(&:email)).index_by(&:email)
    @languages = Language.all.index_by(&:code)
  end

  def new
    @volunteer_request = VolunteerRequest.new(language_code: params[:language])
  end

  # A bot (honeypot filled, form too fast or forged), a duplicate or a flood gets the same answer as a stored
  # request, and nothing is stored
  def create
    @volunteer_request = VolunteerRequest.new(params.require(:volunteer_request).permit(:name, :email, :language_code)
                                                    .merge(locale: I18n.locale.to_s))
    return thank(log: "bot") if params[:website].present? || !VolunteerRequest::FormToken.valid?(params[:form_token])
    return render(:new, status: :unprocessable_entity) unless @volunteer_request.valid?
    return thank(log: "duplicate") if @volunteer_request.duplicate?
    return thank(log: "pending cap") if VolunteerRequest.pending.count >= VolunteerRequest::PENDING_MAX

    @volunteer_request.save!
    @volunteer_request.recipients.each { |admin| VolunteerMailer.requested(@volunteer_request, admin).deliver_later }
    thank
  end

  # Then on to the user's page, to invite them
  def accept
    return redirect_to(volunteers_path) unless @volunteer_request.pending?

    user = @volunteer_request.accept!(current_user)
    redirect_to edit_user_path(user), notice: t(".accepted", name: user.name, language: @volunteer_request.language_name)
  end

  def reject
    @volunteer_request.reject!(current_user) if @volunteer_request.pending?
    redirect_to volunteers_path
  end

  private

  def redirect_logged_in
    redirect_to help_path if current_user
  end

  def set_volunteer_request
    @volunteer_request = VolunteerRequest.find(params[:id])
  end

  def thank(log: nil)
    Rails.logger.info("Volunteer request dropped (#{log})") if log
    redirect_to new_session_path, notice: t("volunteers.create.thanks")
  end
end
