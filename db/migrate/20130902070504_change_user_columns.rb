class ChangeUserColumns < ActiveRecord::Migration
  def up
    add_column :users, :oauth_secret, :string
  end

  def down
    remove_column :users, :oauth_secret
  end
end
