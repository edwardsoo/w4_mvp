class User < ActiveRecord::Base
  attr_accessible :name, :oauth_token, :oauth_secret, :provider, :uid, :username, :profileImage
  
  def self.create_with_omniauth(auth)
    create! do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.name = auth.info.name
      user.oauth_token = auth.credentials.token
      user.oauth_secret = auth.credentials.secret
      user.username = auth.info.nickname
      user.profileImage = auth.info.image
    end
  end
end
