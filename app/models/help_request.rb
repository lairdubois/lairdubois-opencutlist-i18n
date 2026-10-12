# A message from the help page to the admins, kept here (listed on help_requests#index until resolved) and mailed
# to them when e-mails are enabled. page / language : where the user came from, for context.
class HelpRequest < ApplicationRecord
  belongs_to :user
  belongs_to :language, optional: true

  validates :body, presence: true, length: { maximum: 5000 }

  scope :unresolved, -> { where(resolved_at: nil) }

  # The page the help link was clicked on : an app path only, never another site
  def self.safe_page(path)
    path if path.is_a?(String) && path.match?(%r{\A/(?![/\\])}) && path.length <= 500
  end

  def resolved?
    resolved_at.present?
  end

  # Admins hear about it, the sender aside (an admin asking the others), disabled ones too
  def recipients
    User.enabled.where(admin: true).where.not(id: user_id)
  end
end
