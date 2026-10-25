# Discussion about a unit, for one language or for all of them (language nil).
# A question stays open until someone resolves it. An admin note (admin_only) is seen by the admins alone,
# never a question, and stays open the same way.
# Both take replies (parent, one level) : plain comments of the same language and visibility, without a state of their own.
class Comment < ApplicationRecord
  belongs_to :unit
  belongs_to :language, optional: true
  belongs_to :user
  belongs_to :parent, class_name: "Comment", optional: true, inverse_of: :replies
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy

  validates :body, presence: true
  validate :parent_takes_replies, if: :parent

  default_scope { order(:created_at) }
  scope :visible_in, ->(language) { where(language: [nil, language]) }
  scope :visible_to, ->(user) { user.admin? ? all : where(admin_only: false) }
  scope :open_questions, -> { where(question: true, resolved_at: nil, parent_id: nil) }
  scope :open_admin_notes, -> { where(admin_only: true, resolved_at: nil, parent_id: nil) }

  def resolved?
    resolved_at.present?
  end

  def reply?
    parent_id.present?
  end

  # A question or an admin note, not a reply
  def takes_replies?
    !reply? && (question || admin_only)
  end

  def open_question?
    takes_replies? && question && !resolved?
  end

  def open_admin_note?
    takes_replies? && admin_only && !resolved?
  end

  private

  def parent_takes_replies
    errors.add(:parent, :invalid) unless parent.takes_replies? && parent.unit_id == unit_id
  end
end
