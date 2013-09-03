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

      @user = current_user
      render "index"
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

      info = self.get_twitter_user_info(current_user, uid)
      if info[:friends_count].to_i >= 5000
        render :status => :forbidden, :text => "#{info[:screen_name]} has too many friends"
      return
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
          if @friends.empty?
            # Try to find from db
            @db_following = Following.find_by_uid(uid.to_s)
            if @db_following.nil?
              render :status => :forbidden, :text => "Twitter API limit exceeded, cannot get friends of " + info[:screen_name]
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

      info = self.get_twitter_user_info(current_user, uid)
      if info[:followers_count].to_i >= 5000
        render :status => :forbidden, :text => "#{info[:screen_name]} has too many followers"
      return
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
          Rails.cache.write(cacheKey, @followers.to_json, tti: 0.seconds, ttl: 1.day)
          render json: @followers.slice(page.to_i * 10, (page.to_i + 1) * 10 )
          return
        rescue Twitter::Error
          if @followers.empty?
            # Try to find from db
            @db_followers = Follower.find_by_uid(uid.to_s)
            if @db_followers.nil?
              render :status => :forbidden, :text => "Twitter API rate exceeded, cannot get followers of " + info[:screen_name]
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

  def get_twitter_user_info(user, id)
    cacheKey = "twitter_user_info_" + id.to_s;
    data = Rails.cache.read(cacheKey);

    if (data.nil?)
      Twitter.configure do |config|
        config.consumer_key = TWITTER_CONFIG['key']
        config.consumer_secret = TWITTER_CONFIG['secret']
        config.oauth_token = current_user.oauth_token
        config.oauth_token_secret = current_user.oauth_secret
      end
      u = Twitter.user(id.to_i, {:skip_status => 1})
      info = {:screen_name => u.screen_name, :id => u.id, :friends_count => u.friends_count, :followers_count => u.followers_count}
      Rails.cache.write(cacheKey, info.to_json, tti: 0.seconds, ttl: 1.day)
    else
      info = JSON.parse(data, :symbolize_names => true)
    end
    return info
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