Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :messages, only: [:index, :create]
  root "messages#index"
end
