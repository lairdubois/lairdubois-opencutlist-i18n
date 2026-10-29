class AddOriginToGlossaryRevisions < ActiveRecord::Migration[8.1]
  def change
    add_column :glossary_revisions, :origin, :string
  end
end
