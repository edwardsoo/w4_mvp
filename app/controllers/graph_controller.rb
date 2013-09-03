class GraphController < ApplicationController
  def index
    if !current_user
      redirect_to '/login'
    else

    # Create Twitter API object
      Twitter.configure do |config|
        config.consumer_key = TWITTER_CONFIG['key']
        config.consumer_secret = TWITTER_CONFIG['secret']
        config.oauth_token = current_user.oauth_token
        config.oauth_token_secret = current_user.oauth_secret
      end
      @user = Twitter.user
      render "index"
    end
  end

  def user
    if !current_user
      redirect_to '/login'
    else
      if params[:id].present?
        uid = params[:id]
      else
        uid = current_user.uid
      end
      
      cacheKey = "twitter_user_" + uid.to_s;
      @user = Rails.cache.read(cacheKey);
      if (@user.nil?)
        begin
          result = self.get_twitter_user(!current_user, uid)
          @user = {:screen_name => result.screen_name, :id => result.id, :profile_image_url_https => result.profile_image_url_https}
          Rails.cache.write(cacheKey, @user.to_json, tti: 0.seconds, ttl: 1.day)
        rescue Twitter::Error
          render :status => :forbidden, :text => "API rate limit exceeded"
          return
        end
      end
      render json: @user
    end
  end

  def friends
    if !current_user
      redirect_to '/login'
    else
      if params[:id].present?
        uid = params[:id]
      else
        uid = current_user.uid
      end
      
      cacheKey = "twitter_friends_" + uid.to_s;
      
      # Try to read from cache
      @friends = Rails.cache.read(cacheKey);
      if (@friends.nil?)
        begin
          # Make API call
          result = self.get_twitter_friends(!current_user, uid)
          @friends = []
          result.each do |f|
            @friends << {:screen_name => f.screen_name, :id => f.id, :profile_image_url_https => f.profile_image_url_https}
          end
          following = Following.new(:uid => uid.to_s, :json => @friends.to_json)
          following.save
          Rails.cache.write(cacheKey, @friends.to_json, tti: 0.seconds, ttl: 1.day)
        rescue Twitter::Error
          # Try to find from db
          @following = Following.find_by_uid(uid.to_s)
          if @following.nil?
            render :status => :forbidden, :text => "API rate limit exceeded"
          else
            render json: @following.json
          end
          return
        end
      end
      render json: @friends
    end
  end
  
  def followers
    if !current_user
      redirect_to '/login'
    else
      if params[:id].present?
        uid = params[:id]
      else
        uid = current_user.uid
      end
      
      cacheKey = "twitter_followers_" + uid.to_s;
      
      # Try to read from cache
      @followers = Rails.cache.read(cacheKey);
      if (@followers.nil?)
        begin
          # Make API call
          result = self.get_twitter_followers(!current_user, uid)
          @followers = []
          result.each do |f|
            @followers << {:screen_name => f.screen_name, :id => f.id, :profile_image_url_https => f.profile_image_url_https}
          end
          following = Follower.new(:uid => uid.to_s, :json => @followers.to_json)
          following.save
          Rails.cache.write(cacheKey, @followers.to_json, tti: 0.seconds, ttl: 600.seconds)
        rescue Twitter::Error
          # Try to find from db
          @followers = Follower.find_by_uid(uid.to_s)
          if @followers.nil?
            render :status => :forbidden, :text => "API rate limit exceeded"
          else
            render json: @followers.json
          end
          return
        end
      end
      render json: @followers
    end
  end

  protected

  def get_twitter_user(user, id)
    Twitter.configure do |config|
      config.consumer_key = TWITTER_CONFIG['key']
      config.consumer_secret = TWITTER_CONFIG['secret']
      config.oauth_token = current_user.oauth_token
      config.oauth_token_secret = current_user.oauth_secret
    end
    return Twitter.user(id.to_i, {:skip_status => 1})
  end

  def get_twitter_friends(user, id)
    Twitter.configure do |config|
      config.consumer_key = TWITTER_CONFIG['key']
      config.consumer_secret = TWITTER_CONFIG['secret']
      config.oauth_token = current_user.oauth_token
      config.oauth_token_secret = current_user.oauth_secret
    end
    return Twitter.friends(id.to_i, {:skip_status => 1})
  end

  def get_twitter_followers(user, id)
    Twitter.configure do |config|
      config.consumer_key = TWITTER_CONFIG['key']
      config.consumer_secret = TWITTER_CONFIG['secret']
      config.oauth_token = current_user.oauth_token
      config.oauth_token_secret = current_user.oauth_secret
    end
    return Twitter.followers(id.to_i, {:skip_status => 1})
  end

end