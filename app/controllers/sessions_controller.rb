class SessionsController < ApplicationController
  def create
    # raise request.env["omniauth.auth"].to_yaml
     
    auth = request.env["omniauth.auth"]
    logger.debug "auth: #{@auth}"
    user = User.create_with_omniauth(auth)
    session[:user_id] = user.id
    redirect_to '/graph'
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_url
  end
end