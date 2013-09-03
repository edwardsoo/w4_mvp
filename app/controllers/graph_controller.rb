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
          result = self.get_twitter_user(current_user, uid)
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

      if params[:page].present?
        page = params[:page]
      else
        page = '0'
      end

      cacheKey = "twitter_friends_" + uid.to_s;

      # Try to read from cache
      @friends = Rails.cache.read(cacheKey);
      if (@friends.nil?)
        @friends = []
        begin
        # Make API call
          ids = self.get_twitter_friend_ids(current_user, uid)
          ids.each_slice(100) do |a|
            users = self.get_twitter_users(current_user, a)
            users.each do |f|
              @friends << {:screen_name => f.screen_name, :id => f.id, :profile_image_url_https => f.profile_image_url_https}
            end
          end
          following = Following.new(:uid => uid.to_s, :json => @friends.to_json)
          following.save
          Rails.cache.write(cacheKey, @friends.to_json, tti: 0.seconds, ttl: 1.day)
          render json: @friends.slice(page.to_i * 10, (page.to_i + 1) * 10 )
          return
        rescue Twitter::Error
          if @friends.empty
            # Try to find from db
            @db_following = Following.find_by_uid(uid.to_s)
            if @db_following.nil?
              render :status => :forbidden, :text => "API rate limit exceeded"
            return
            else
              @friends = @db_following.json
            end
          end
        end
      end
      render json: JSON.parse(@friends).slice(page.to_i * 10, (page.to_i + 1) * 10 )
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

      if params[:page].present?
        page = params[:page]
      else
        page = '0'
      end

      cacheKey = "twitter_followers_" + uid.to_s;

      # Try to read from cache
      @followers = Rails.cache.read(cacheKey);
      if (@followers.nil?)
        @followers = []
        begin
        # Make API call
          ids = self.get_twitter_follower_ids(current_user, uid)
          ids.each_slice(100) do |a|
            users = self.get_twitter_users(current_user, a)
            users.each do |f|
              @followers << {:screen_name => f.screen_name, :id => f.id, :profile_image_url_https => f.profile_image_url_https}
            end
          end
          follower = Follower.new(:uid => uid.to_s, :json => @followers.to_json)
          follower.save
          Rails.cache.write(cacheKey, @followers.to_json, tti: 0.seconds, ttl: 600.seconds)
          render json: @followers.slice(page.to_i * 10, (page.to_i + 1) * 10 )
          return
        rescue Twitter::Error
          if @followers.empty
            # Try to find from db
            @db_followers = Follower.find_by_uid(uid.to_s)
            if @db_followers.nil?
              render :status => :forbidden, :text => "API rate limit exceeded"
            return
            else
              @followers = @db_followers.json
            end
          end
        end
      end
      render json: JSON.parse(@followers).slice(page.to_i * 10, (page.to_i + 1) * 10 )
    end
  end

  protected

  def get_twitter_users(user, ids)
    Twitter.configure do |config|
      config.consumer_key = TWITTER_CONFIG['key']
      config.consumer_secret = TWITTER_CONFIG['secret']
      config.oauth_token = current_user.oauth_token
      config.oauth_token_secret = current_user.oauth_secret
    end
    return Twitter.users(ids, {:include_entities  => false})
  end

  def get_twitter_user(user, id)
    Twitter.configure do |config|
      config.consumer_key = TWITTER_CONFIG['key']
      config.consumer_secret = TWITTER_CONFIG['secret']
      config.oauth_token = current_user.oauth_token
      config.oauth_token_secret = current_user.oauth_secret
    end
    return Twitter.user(id.to_i, {:skip_status => 1})
  end

  def get_twitter_friend_ids(user, id)
    Twitter.configure do |config|
      config.consumer_key = TWITTER_CONFIG['key']
      config.consumer_secret = TWITTER_CONFIG['secret']
      config.oauth_token = current_user.oauth_token
      config.oauth_token_secret = current_user.oauth_secret
    end
    return Twitter.friend_ids(id.to_i)
  end

  def get_twitter_follower_ids(user, id)
    Twitter.configure do |config|
      config.consumer_key = TWITTER_CONFIG['key']
      config.consumer_secret = TWITTER_CONFIG['secret']
      config.oauth_token = current_user.oauth_token
      config.oauth_token_secret = current_user.oauth_secret
    end
    return Twitter.follower_ids(id.to_i)
  end

end