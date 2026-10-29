# The languages a user keeps in the glossary's table view (codes, comma-separated ; nil : all of them)
class AddGlossaryColumnsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :glossary_columns, :string
  end
end
