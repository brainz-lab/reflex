Rails.application.routes.draw do
  # API
  namespace :api do
    namespace :v1 do
      # Browser SDK endpoint (for brainzlab-js)
      match "browser", to: "browser#preflight", via: :options
      post "browser", to: "browser#create"

      # Project provisioning (internal API for SDK auto-setup)
      post "projects/provision", to: "projects#provision"
      get "projects/lookup", to: "projects#lookup"
      post "projects/:platform_project_id/archive", to: "projects#archive"
      post "projects/:platform_project_id/unarchive", to: "projects#unarchive"
      post "projects/:platform_project_id/purge", to: "projects#purge"

      # Ingest errors
      post "errors", to: "events#create"
      post "errors/batch", to: "events#batch"

      # Capture messages (without exception)
      post "messages", to: "events#create_message"

      # Query errors
      resources :errors, only: [ :index, :show ] do
        member do
          post :resolve
          post :ignore
          post :unresolve
          get :events
        end
        collection do
          # Signal integration endpoints
          get :query
          get :baseline
          get :last
        end
      end
    end
  end

  # MCP Server
  namespace :mcp do
    get "tools", to: "tools#index"
    post "tools/:name", to: "tools#call"
    post "rpc", to: "tools#rpc"
  end

  # Dashboard
  namespace :dashboard do
    resources :assistant, only: [ :index, :show, :create ] do
      member do
        post :message
      end
    end

    resources :projects, only: [ :index, :show, :new, :create, :edit, :update ] do
      member do
        get :setup
        get :mcp_setup
        post :regenerate_mcp_token
        get :analytics
        get :settings, to: "projects#edit"
      end
      resources :errors, only: [ :index, :show ] do
        member do
          post :resolve
          post :ignore
          post :unresolve
        end
        resources :events, only: [ :index, :show ]
      end
    end
    root to: "projects#index"

    # Dev Tools (development only)
    resource :dev_tools, only: [ :show ], controller: "dev_tools" do
      post "clean_errors"
      post "clean_all"
    end
  end

  # SSO from Platform
  get "sso/callback", to: "sso#callback"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # WebSocket
  mount ActionCable.server => "/cable"

  root "dashboard/projects#index"
end
