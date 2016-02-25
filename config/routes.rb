Rails.application.routes.draw do

  resources :customers, only: [:index]
  devise_for :users
  root "dashboard#index"
  # Serve websocket cable requests in-process
  # mount ActionCable.server => '/cable'
end
