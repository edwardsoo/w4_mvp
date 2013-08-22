class CreateFollowers < ActiveRecord::Migration
  def change
    create_table :followers do |t|
      t.string :uid
      t.text :json

      t.timestamps
    end
    
    add_index :followers, :uid
  end
end
