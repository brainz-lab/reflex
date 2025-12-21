Rails.application.routes.draw do
  # API
  namespace :api do
    namespace :v1 do
      # Ingest errors
      post 'errors', to: 'events#create'
      post 'errors/batch', to: 'events#batch'

      # Query errors
      resources :errors, only: [:index, :show] do
        member do
          post :resolve
          post :ignore
          post :unresolve
        end
      end
    end
  end

  # MCP Server
  namespace :mcp do
    get 'tools', to: 'tools#index'
    post 'tools/:name', to: 'tools#call'
    post 'rpc', to: 'tools#rpc'
  end

  # Dashboard
  namespace :dashboard do
    root to: 'errors#index'
    resources :errors, only: [:index, :show] do
      member do
        post :resolve
        post :ignore
        post :unresolve
      end
      resources :events, only: [:index, :show]
    end
  end

  # Health check
  get 'up' => 'rails/health#show', as: :rails_health_check

  # WebSocket
  mount ActionCable.server => '/cable'

  root 'dashboard/errors#index'
end
