# An invitation e-mail actually sent (InvitationMailer, after delivery) : the address it went to (the user's may
# change since), who sent it (nil once that admin is deleted). Shown on the user's page
class Invitation < ApplicationRecord
  belongs_to :user
  belongs_to :inviter, class_name: "User", optional: true
end
