# Where the OCL repo lives and how we publish to it
Rails.configuration.x.ocl = ActiveSupport::OrderedOptions.new.tap do |c|
  c.github_repo = ENV.fetch("OCL_GITHUB_REPO", "lairdubois/lairdubois-opencutlist-sketchup-extension")
  c.repo_url = ENV.fetch("OCL_REPO_URL", "https://github.com/#{c.github_repo}.git") # a local path works for tests
  c.base_branch = ENV.fetch("OCL_BASE_BRANCH", "master")
  c.i18n_branch = ENV.fetch("OCL_I18N_BRANCH", "i18n/updates")
  c.github_app_id = ENV["OCL_GITHUB_APP_ID"]
  c.github_app_private_key = ENV["OCL_GITHUB_APP_PRIVATE_KEY"] # the PEM, or a path to it
  c.github_app_client_id = ENV["OCL_GITHUB_APP_CLIENT_ID"] # with the secret : admins connect their own account
  c.github_app_client_secret = ENV["OCL_GITHUB_APP_CLIENT_SECRET"]
  c.github_token = ENV["OCL_GITHUB_TOKEN"] # fallback when no GitHub App is configured
  c.api_url = ENV.fetch("OCL_GITHUB_API_URL", "https://api.github.com")
  c.web_url = ENV.fetch("OCL_GITHUB_WEB_URL", "https://github.com") # OAuth endpoints
  c.webhook_secret = ENV["OCL_GITHUB_WEBHOOK_SECRET"]
  c.api_token = ENV["OCL_API_TOKEN"] # bearer token of /api/suggestions (Claude Code) ; the API is off while empty
  c.checkout_dir = ENV.fetch("OCL_CHECKOUT_DIR", Rails.root.join("storage", "ocl_repo").to_s)
end
