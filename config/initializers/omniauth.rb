FACEBOOK_CONFIG = YAML.load_file("#{::Rails.root}/config/facebook.yml")[::Rails.env]
TWITTER_CONFIG = YAML.load_file("#{::Rails.root}/config/twitter.yml")[::Rails.env]

# Rails.application.config.middleware.use OmniAuth::Builder do
  # provider :facebook, FACEBOOK_CONFIG['app_id'], FACEBOOK_CONFIG['secret']
# end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :twitter, TWITTER_CONFIG['key'], TWITTER_CONFIG['secret']
end