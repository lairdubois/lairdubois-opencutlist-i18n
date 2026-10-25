# Who hears about a comment : admins and the language's reviewers for a question,
# everyone who already took part in the discussion otherwise, the question's author and repliers for a reply.
# Never the author, nor a disabled user.
class CommentNotifier
  def initialize(comment)
    @comment = comment
  end

  def call
    recipients.each { |user| CommentMailer.posted(@comment, user).deliver_later }
  end

  # An admin note : nobody
  def recipients
    return [] if @comment.admin_only

    users = if @comment.reply?
      [@comment.parent.user, *@comment.parent.replies.includes(:user).map(&:user)]
    else
      @comment.unit.comments.visible_in(@comment.language).includes(:user).map(&:user)
    end
    if @comment.question
      users += User.where(admin: true)
      users += User.joins(:memberships).merge(Membership.reviewer).where(memberships: { language_id: @comment.language_id }) if @comment.language
    end
    users.uniq.reject(&:disabled?) - [@comment.user]
  end
end
