# The help page : a guide of the tool and a form to write to the admins (HelpRequestsController#create).
# from : the page the help link was clicked on, sent along with the message
class HelpController < ApplicationController
  def show
    @page = HelpRequest.safe_page(params[:from])
    @open_count = HelpRequest.unresolved.count if current_user.admin?
  end
end
