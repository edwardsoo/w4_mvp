class CreateFollowings < ActiveRecord::Migration
  def change
    create_table :followings do |t|
      t.string :uid
      t.text :json

      t.timestamps
    end
    
    add_index :followings, :uid
  end
end
