class CreateHelpRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :help_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.references :language, foreign_key: true
      t.text :body, null: false
      t.string :page
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :help_requests, :resolved_at
  end
end
