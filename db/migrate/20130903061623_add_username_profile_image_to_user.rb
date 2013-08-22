class AddUsernameProfileImageToUser < ActiveRecord::Migration
  def up
    add_column :users, :username, :string
    add_column :users, :profileImage, :string
  end

  def down
    remove_column :users, :username
    remove_column :users, :profileImage
  end
end
