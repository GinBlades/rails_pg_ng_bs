Rails.application.routes.draw do
  devise_for :users
  get 'dashboard/index'

  root "dashboard#index"
  # Serve websocket cable requests in-process
  # mount ActionCable.server => '/cable'
end
