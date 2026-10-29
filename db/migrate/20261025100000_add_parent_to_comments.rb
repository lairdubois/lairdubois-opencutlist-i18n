class AddParentToComments < ActiveRecord::Migration[8.1]
  def change
    add_reference :comments, :parent, foreign_key: { to_table: :comments }
  end
end
