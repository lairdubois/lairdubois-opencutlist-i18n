class CreateIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :issues do |t|
      t.references :language, null: false, foreign_key: true
      t.references :unit, foreign_key: true
      t.string :kind, null: false
      t.text :body, null: false
      t.text :text
      t.string :origin
      t.datetime :closed_at
      t.references :closed_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :issues, [:language_id, :closed_at]
  end
end
