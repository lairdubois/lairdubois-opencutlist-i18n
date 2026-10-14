class VolunteerMailer < ApplicationMailer
  def requested(volunteer_request, admin)
    @volunteer_request = volunteer_request
    recipient_locale(admin) do
      mail to: admin.email, reply_to: volunteer_request.email,
           subject: t(".subject", name: volunteer_request.name, language: volunteer_request.language_name)
    end
  end
end
