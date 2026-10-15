# The API used from outside (Claude Code, run by an admin), with the OCL_API_TOKEN bearer token (404 while unset),
# on one target language
class Api::BaseController < ActionController::API
  MAX_LIMIT = 200

  before_action :authenticate
  before_action :set_language

  private

  def authenticate
    token = Rails.configuration.x.ocl.api_token
    return head :not_found if token.blank?

    given = request.authorization.to_s.delete_prefix("Bearer ")
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(given, token)
  end

  def set_language
    @language = Language.targets.find_by(code: params[:language])
    head :not_found unless @language
  end

  def limit(default)
    params.fetch(:limit, default).to_i.clamp(1, self.class::MAX_LIMIT)
  end
end
