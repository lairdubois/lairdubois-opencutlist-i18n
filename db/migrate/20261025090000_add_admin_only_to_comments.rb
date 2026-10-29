class AddAdminOnlyToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :admin_only, :boolean, default: false, null: false
  end
end
