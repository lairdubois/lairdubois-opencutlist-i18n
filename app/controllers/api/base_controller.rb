# The API used from outside (Claude Code, run by an admin), with the OCL_API_TOKEN bearer token (404 while unset),
# on one target language
class Api::BaseController < ActionController::API
  MAX_LIMIT = 200
  # Shown as the author of what the API writes (issues, glossary changes) : the robot behind it
  ORIGIN = "OpenCutBot".freeze

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

  def glossary_operations
    GlossaryOperations.new(nil, origin: ORIGIN)
  end

  # A batch of at most MAX_LIMIT items, else a 422 rendered (nil)
  def batch(name)
    items = params.require(name)
    return items if items.size <= MAX_LIMIT

    render json: { error: "at most #{MAX_LIMIT} #{name} per request" }, status: :unprocessable_content
    nil
  end

  def limit(default)
    params.fetch(:limit, default).to_i.clamp(1, self.class::MAX_LIMIT)
  end
end
