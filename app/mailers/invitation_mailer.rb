# Invitation : no login token (it could sit unread in a mailbox), only the site
# and the address to log in with, which then gets a short-lived single-use link
class InvitationMailer < ApplicationMailer
  def invite(user, inviter)
    @user = user
    @inviter = inviter
    @memberships = user.memberships.includes(:language).sort_by { |m| m.language.name }
    @url = root_url
    recipient_locale(user) { mail to: user.email, subject: t(".subject") }
  end
end
