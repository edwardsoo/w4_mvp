class Follower < ActiveRecord::Base
  attr_accessible :json, :uid
  
  validates_uniqueness_of :uid
  validates :uid, presence: true
  validates :json, presence: true
end
