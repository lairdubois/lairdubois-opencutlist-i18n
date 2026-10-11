require "base64"

# After a push to the base branch : reads the pushed fr.yml through the GitHub API and flags it
# only when it has changes to sync (the test Publisher refuses on). Judging the content rather than the
# commits means merging the tool's own pull request is not a change, whatever the merge method and author.
class RepoFrCheckJob < ApplicationJob
  queue_as :default

  def perform(sha)
    return unless Baseline.current

    config = Rails.configuration.x.ocl
    path = "#{OclRepo::I18N_SRC}/#{Language::SOURCE_CODE}.yml"
    file = GithubApi.request(:get, "/repos/#{config.github_repo}/contents/#{path}?ref=#{sha}", token: GithubAuth.new(config).token)
    text = Base64.decode64(file.fetch("content")).force_encoding("UTF-8")
    SourceSync.new(text, author: nil).plan.empty? ? clear : flag
  rescue GithubApi::NotFound
    flag # fr.yml deleted or moved : the sync page tells it
  end

  private

  def flag
    Setting["repo_fr_changed_at"] ||= Time.current.iso8601 # the first push seen with changes to sync
  end

  def clear
    Setting["repo_fr_changed_at"] = nil
  end
end
