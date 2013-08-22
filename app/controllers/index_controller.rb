class IndexController < ApplicationController
  def index
    if !current_user
      redirect_to '/login'
    else
      redirect_to "/graph"
    end
  end
  
  def login
    render "index/home"
  end
end