# Append-only history of everything that happens to a unit
class Revision < ApplicationRecord
  KINDS = %w[import create rename source_minor source_major note translate review archive restore].freeze

  belongs_to :unit
  belongs_to :language, optional: true
  belongs_to :user, optional: true

  validates :kind, inclusion: { in: KINDS }

  default_scope { order(:created_at, :id) }

  scope :by_user, ->(user) { where(user_id: user.id) }

  # Users with a revision in the scope, by name
  def self.users
    User.where(id: unscope(:order).where.not(user_id: nil).select(:user_id)).order(:name)
  end
end
