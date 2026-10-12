class HelpMailer < ApplicationMailer
  def requested(help_request, admin)
    @help_request = help_request
    @page_url = URI.join(root_url, help_request.page).to_s if help_request.page
    recipient_locale(admin) do
      mail to: admin.email, reply_to: help_request.user.email,
           subject: t(".subject", name: help_request.user.name)
    end
  end
end
