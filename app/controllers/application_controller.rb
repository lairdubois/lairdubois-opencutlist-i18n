class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  around_action :switch_locale
  before_action :require_login
  before_action :record_last_seen
  helper_method :current_user

  private

  def current_user
    @current_user ||= User.enabled.find_by(id: session[:user_id]) if session[:user_id]
  end

  def switch_locale(&)
    I18n.with_locale(current_user&.locale.presence || browser_locale || I18n.default_locale, &)
  end

  # First supported language of the Accept-Language header
  def browser_locale
    request.headers["Accept-Language"].to_s.scan(/([a-z]{2})(?:-[A-Za-z]+)?/i).map { |(code)| code.downcase.to_sym }
           .find { |code| I18n.available_locales.include?(code) }
  end

  def require_login
    redirect_to new_session_path unless current_user
  end

  # Any request of a logged in user, consultation included, written at most every User::SEEN_PRECISION
  def record_last_seen
    user = current_user
    user.update_column(:last_seen_at, Time.current) if user && (user.last_seen_at.nil? || user.last_seen_at < User::SEEN_PRECISION.ago)
  end

  def require_admin
    redirect_to translate_root_path, alert: t("flash.admin_only") unless current_user&.admin?
  end

  def current_author
    current_user
  end
end
