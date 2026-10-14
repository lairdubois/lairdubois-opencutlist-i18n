# Invitation : no login token (it could sit unread in a mailbox), only the site
# and the address to log in with, which then gets a short-lived single-use link
class InvitationMailer < ApplicationMailer
  # Recorded once delivered (Invitation) : not when e-mails are off (perform_deliveries), nor when delivery raised
  after_deliver :record_invitation

  def invite(user, inviter)
    @user = user
    @inviter = inviter
    @memberships = user.memberships.includes(:language).sort_by { |m| m.language.name }
    @url = root_url
    recipient_locale(user) { mail to: user.email, subject: t(".subject") }
  end

  private

  def record_invitation
    Invitation.create!(user: @user, inviter: @inviter, email: message.to.first) if message.perform_deliveries
  end
end
