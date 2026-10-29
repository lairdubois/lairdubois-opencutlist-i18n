# The Transifex migration is gone : its imported revisions ("transifex:<username>", no user) are tied to their user
# as the tool's own are (user + name), before the column goes. Authors with no account keep their text.
class RemoveTransifexUsernameFromUsers < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE revisions
      SET user_id = (SELECT users.id FROM users WHERE 'transifex:' || users.transifex_username = revisions.author),
          author = (SELECT users.name FROM users WHERE 'transifex:' || users.transifex_username = revisions.author)
      WHERE user_id IS NULL
        AND author IN (SELECT 'transifex:' || transifex_username FROM users WHERE transifex_username IS NOT NULL)
    SQL
    remove_index :users, :transifex_username
    remove_column :users, :transifex_username
  end

  # The revisions stay tied to their users
  def down
    add_column :users, :transifex_username, :string
    add_index :users, :transifex_username, unique: true
  end
end
