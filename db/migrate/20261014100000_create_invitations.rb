class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :inviter, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :email, null: false
      t.datetime :created_at, null: false
    end
  end
end
