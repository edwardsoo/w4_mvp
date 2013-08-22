W4Mvp::Application.routes.draw do

  match 'auth/:provider/callback', to: 'sessions#create'
  match 'auth/failure', to: redirect('/')
  match 'signout', to: 'sessions#destroy', as: 'signout'

  match 'login' => "index#login"
  
  match 'graph' => "graph#index"
  match 'graph/friends' => "graph#friends"
  match 'graph/followers' => "graph#followers"
  match 'graph/user' => "graph#user"
  
  root :to => 'index#index'
end
