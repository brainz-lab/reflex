Rails.application.routes.draw do
  # API
  namespace :api do
    namespace :v1 do
      # Project provisioning (internal API for SDK auto-setup)
      post 'projects/provision', to: 'projects#provision'
      get 'projects/lookup', to: 'projects#lookup'

      # Ingest errors
      post 'errors', to: 'events#create'
      post 'errors/batch', to: 'events#batch'

      # Capture messages (without exception)
      post 'messages', to: 'events#create_message'

      # Query errors
      resources :errors, only: [:index, :show] do
        member do
          post :resolve
          post :ignore
          post :unresolve
          get :events
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
    resources :projects, only: [:index, :show, :new, :create, :edit, :update] do
      member do
        get :setup
        get :mcp_setup
        get :analytics
        get :settings, to: 'projects#edit'
      end
      resources :errors, only: [:index, :show] do
        member do
          post :resolve
          post :ignore
          post :unresolve
        end
        resources :events, only: [:index, :show]
      end
    end
    root to: 'projects#index'
  end

  # Health check
  get 'up' => 'rails/health#show', as: :rails_health_check

  # WebSocket
  mount ActionCable.server => '/cable'

  root 'dashboard/projects#index'
end
