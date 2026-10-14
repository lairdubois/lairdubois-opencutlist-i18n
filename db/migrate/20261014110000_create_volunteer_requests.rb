class CreateVolunteerRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :volunteer_requests do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :language_code, null: false
      t.string :locale
      t.integer :status, null: false, default: 0
      t.references :user, foreign_key: true
      t.references :handled_by, foreign_key: { to_table: :users }
      t.datetime :handled_at
      t.timestamps
    end
    add_index :volunteer_requests, :status
  end
end
