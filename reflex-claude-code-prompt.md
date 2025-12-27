# Claude Code Prompt: Build Reflex by Brainz Lab

## Project Overview

Build **Reflex** - error tracking with instant reaction for Rails apps. Second product in the Brainz Lab suite.

> *"Instant reaction to errors"*
> 
> reflex.brainzlab.ai

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│                              REFLEX                                          │
│                         (Rails 8 App)                                        │
│                                                                              │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│   │   Dashboard     │  │      API        │  │   MCP Server    │            │
│   │   (Hotwire)     │  │   (JSON API)    │  │   (Ruby)        │            │
│   │                 │  │                 │  │                 │            │
│   │  /dashboard/*   │  │  /api/v1/*      │  │  /mcp/*         │            │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘            │
│                              │                      │                       │
│                              ▼                      ▼                       │
│                    ┌─────────────────────────────────────┐                 │
│                    │         PostgreSQL + JSONB          │                 │
│                    └─────────────────────────────────────┘                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                       ▲
                                       │
                    ┌──────────────────┴──────────────────┐
                    │                                      │
            ┌───────┴───────┐                    ┌────────┴────────┐
            │  SDK (Gem)    │                    │  Claude/AI      │
            │               │                    │                 │
            │ brainzlab-sdk │                    │  Uses MCP       │
            │               │                    │  tools          │
            └───────────────┘                    └─────────────────┘
```

## Tech Stack

- **Backend**: Rails 8 API + Dashboard
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS
- **Database**: PostgreSQL with JSONB
- **Background Jobs**: Solid Queue
- **Caching**: Solid Cache
- **WebSockets**: Solid Cable (real-time errors)
- **MCP Server**: Ruby (inside Rails app)
- **Design**: Clean, minimal like Anthropic/Claude

## Project Structure

```
reflex/
├── Gemfile
├── Dockerfile
├── docker-compose.yml
├── config/
│   ├── routes.rb
│   └── initializers/
├── app/
│   ├── controllers/
│   │   ├── api/v1/
│   │   │   ├── base_controller.rb
│   │   │   ├── errors_controller.rb
│   │   │   └── events_controller.rb
│   │   ├── dashboard/
│   │   │   ├── base_controller.rb
│   │   │   ├── errors_controller.rb
│   │   │   └── events_controller.rb
│   │   ├── mcp/
│   │   │   └── tools_controller.rb
│   │   └── sso_controller.rb
│   ├── models/
│   │   ├── project.rb
│   │   ├── error_group.rb
│   │   └── error_event.rb
│   ├── services/
│   │   ├── error_processor.rb
│   │   ├── fingerprint_generator.rb
│   │   ├── platform_client.rb
│   │   └── mcp/
│   │       ├── server.rb
│   │       └── tools/
│   │           ├── base.rb
│   │           ├── reflex_list.rb
│   │           ├── reflex_show.rb
│   │           ├── reflex_resolve.rb
│   │           ├── reflex_ignore.rb
│   │           ├── reflex_stats.rb
│   │           └── reflex_search.rb
│   ├── jobs/
│   │   ├── process_error_job.rb
│   │   └── send_notification_job.rb
│   ├── channels/
│   │   └── errors_channel.rb
│   ├── views/
│   │   ├── layouts/
│   │   │   └── dashboard.html.erb
│   │   └── dashboard/
│   │       ├── errors/
│   │       │   ├── index.html.erb
│   │       │   └── show.html.erb
│   │       └── events/
│   └── javascript/
│       └── controllers/
│           ├── error_list_controller.js
│           ├── error_detail_controller.js
│           └── live_errors_controller.js
```

---

## Database Schema

```ruby
# db/migrate/001_create_projects.rb

class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')
    
    create_table :projects, id: :uuid do |t|
      t.string :platform_project_id, null: false  # prj_xxx from Platform
      t.string :name
      t.string :environment, default: 'live'      # live or test
      
      t.bigint :error_count, default: 0
      t.bigint :event_count, default: 0
      
      t.timestamps
      
      t.index :platform_project_id, unique: true
    end
  end
end

# db/migrate/002_create_error_groups.rb

class CreateErrorGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :error_groups, id: :uuid do |t|
      t.references :project, type: :uuid, null: false, foreign_key: true
      
      # Identification
      t.string :fingerprint, null: false          # Unique hash for grouping
      t.string :error_class, null: false          # NoMethodError, RuntimeError, etc.
      t.text :message                             # Error message (first occurrence)
      
      # Location
      t.string :file_path                         # app/controllers/users_controller.rb
      t.integer :line_number
      t.string :function_name                     # create, update, etc.
      t.string :controller                        # UsersController
      t.string :action                            # create
      
      # Status
      t.string :status, default: 'unresolved'     # unresolved, resolved, ignored, muted
      t.datetime :resolved_at
      t.string :resolved_by                       # user_id who resolved
      
      # Counts & timing
      t.bigint :event_count, default: 0
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      
      # Context
      t.string :last_commit                       # Git commit when last seen
      t.string :last_environment                  # production, staging
      
      # Notifications
      t.boolean :notifications_enabled, default: true
      t.datetime :last_notified_at
      
      t.timestamps
      
      t.index [:project_id, :fingerprint], unique: true
      t.index [:project_id, :status]
      t.index [:project_id, :last_seen_at]
      t.index [:project_id, :error_class]
      t.index :fingerprint
    end
  end
end

# db/migrate/003_create_error_events.rb

class CreateErrorEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :error_events, id: :uuid do |t|
      t.references :error_group, type: :uuid, null: false, foreign_key: true
      t.references :project, type: :uuid, null: false, foreign_key: true
      
      # Error details
      t.string :error_class, null: false
      t.text :message
      t.jsonb :backtrace, default: []             # Array of stack frames
      
      # Context
      t.string :environment                       # production, staging
      t.string :commit                            # Git SHA
      t.string :branch                            # Git branch
      t.string :release                           # Release/version tag
      t.string :server_name                       # Hostname
      
      # Request context (if web request)
      t.string :request_id
      t.string :request_method                    # GET, POST, etc.
      t.string :request_url
      t.string :request_path
      t.jsonb :request_params, default: {}        # Sanitized params
      t.jsonb :request_headers, default: {}       # Selected headers
      
      # User context
      t.string :user_id
      t.string :user_email
      t.jsonb :user_data, default: {}             # Additional user info
      
      # Additional context
      t.jsonb :context, default: {}               # Custom context from SDK
      t.jsonb :tags, default: {}                  # Tags for filtering
      t.jsonb :extra, default: {}                 # Any extra data
      
      # Breadcrumbs (events leading up to error)
      t.jsonb :breadcrumbs, default: []
      
      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false
      
      t.index [:project_id, :occurred_at]
      t.index [:error_group_id, :occurred_at]
      t.index :request_id
      t.index :user_id
      t.index :commit
    end
    
    # JSONB indexes for querying
    execute "CREATE INDEX index_error_events_on_tags ON error_events USING GIN (tags jsonb_path_ops);"
    execute "CREATE INDEX index_error_events_on_context ON error_events USING GIN (context jsonb_path_ops);"
  end
end
```

---

## Models

```ruby
# app/models/project.rb

class Project < ApplicationRecord
  has_many :error_groups, dependent: :destroy
  has_many :error_events, dependent: :destroy
  
  validates :platform_project_id, presence: true, uniqueness: true
  
  def self.find_or_create_for_platform!(platform_project_id:, name: nil, environment: 'live')
    find_or_create_by!(platform_project_id: platform_project_id) do |p|
      p.name = name
      p.environment = environment
    end
  end
end

# app/models/error_group.rb

class ErrorGroup < ApplicationRecord
  belongs_to :project, counter_cache: :error_count
  has_many :events, class_name: 'ErrorEvent', dependent: :destroy
  
  STATUSES = %w[unresolved resolved ignored muted].freeze
  
  validates :fingerprint, presence: true, uniqueness: { scope: :project_id }
  validates :error_class, presence: true
  validates :status, inclusion: { in: STATUSES }
  
  scope :unresolved, -> { where(status: 'unresolved') }
  scope :resolved, -> { where(status: 'resolved') }
  scope :ignored, -> { where(status: 'ignored') }
  scope :active, -> { where(status: %w[unresolved muted]) }
  scope :recent, -> { order(last_seen_at: :desc) }
  scope :frequent, -> { order(event_count: :desc) }
  
  def resolve!(user_id: nil)
    update!(
      status: 'resolved',
      resolved_at: Time.current,
      resolved_by: user_id
    )
  end
  
  def unresolve!
    update!(
      status: 'unresolved',
      resolved_at: nil,
      resolved_by: nil
    )
  end
  
  def ignore!
    update!(status: 'ignored')
  end
  
  def mute!(duration: nil)
    update!(status: 'muted')
    # TODO: Schedule unmute if duration provided
  end
  
  def record_occurrence!(event)
    update!(
      event_count: event_count + 1,
      last_seen_at: event.occurred_at,
      last_commit: event.commit,
      last_environment: event.environment
    )
    
    # Unresolve if it was resolved and happens again
    unresolve! if resolved?
  end
  
  def resolved?
    status == 'resolved'
  end
  
  def short_message
    message&.lines&.first&.truncate(100)
  end
  
  def location
    return nil unless file_path
    "#{file_path}:#{line_number} in #{function_name}"
  end
end

# app/models/error_event.rb

class ErrorEvent < ApplicationRecord
  belongs_to :error_group, counter_cache: :event_count
  belongs_to :project, counter_cache: :event_count
  
  validates :error_class, presence: true
  validates :occurred_at, presence: true
  
  scope :recent, -> { order(occurred_at: :desc) }
  
  def parsed_backtrace
    backtrace.map do |frame|
      {
        file: frame['file'],
        line: frame['line'],
        function: frame['function'],
        context: frame['context'],  # Lines of code around the error
        in_app: frame['in_app']     # Is this our code or a gem?
      }
    end
  end
  
  def app_backtrace
    parsed_backtrace.select { |f| f[:in_app] }
  end
  
  def first_app_frame
    app_backtrace.first
  end
end
```

---

## Error Processing Service

```ruby
# app/services/error_processor.rb

class ErrorProcessor
  def initialize(project:, payload:)
    @project = project
    @payload = payload.deep_symbolize_keys
  end
  
  def process!
    # Generate fingerprint for grouping
    fingerprint = FingerprintGenerator.generate(@payload)
    
    # Find or create error group
    error_group = find_or_create_group(fingerprint)
    
    # Create event
    event = create_event(error_group)
    
    # Update group stats
    error_group.record_occurrence!(event)
    
    # Broadcast to dashboard
    broadcast_new_error(error_group, event)
    
    # Send notifications if needed
    maybe_notify(error_group, event)
    
    { error_group: error_group, event: event }
  end
  
  private
  
  def find_or_create_group(fingerprint)
    @project.error_groups.find_or_create_by!(fingerprint: fingerprint) do |group|
      group.error_class = @payload[:error_class] || @payload[:exception]&.dig(:class) || 'UnknownError'
      group.message = @payload[:message] || @payload[:exception]&.dig(:message)
      group.file_path = extract_file_path
      group.line_number = extract_line_number
      group.function_name = extract_function_name
      group.controller = @payload.dig(:request, :controller)
      group.action = @payload.dig(:request, :action)
      group.first_seen_at = Time.current
      group.last_seen_at = Time.current
    end
  end
  
  def create_event(error_group)
    error_group.events.create!(
      project: @project,
      error_class: @payload[:error_class] || @payload[:exception]&.dig(:class) || 'UnknownError',
      message: @payload[:message] || @payload[:exception]&.dig(:message),
      backtrace: normalize_backtrace(@payload[:backtrace] || @payload[:exception]&.dig(:backtrace) || []),
      
      environment: @payload[:environment],
      commit: @payload[:commit],
      branch: @payload[:branch],
      release: @payload[:release],
      server_name: @payload[:server_name] || @payload[:host],
      
      request_id: @payload.dig(:request, :id) || @payload[:request_id],
      request_method: @payload.dig(:request, :method),
      request_url: @payload.dig(:request, :url),
      request_path: @payload.dig(:request, :path),
      request_params: sanitize_params(@payload.dig(:request, :params) || {}),
      request_headers: @payload.dig(:request, :headers) || {},
      
      user_id: @payload.dig(:user, :id),
      user_email: @payload.dig(:user, :email),
      user_data: @payload[:user] || {},
      
      context: @payload[:context] || {},
      tags: @payload[:tags] || {},
      extra: @payload[:extra] || {},
      breadcrumbs: @payload[:breadcrumbs] || [],
      
      occurred_at: parse_timestamp(@payload[:timestamp]) || Time.current
    )
  end
  
  def normalize_backtrace(backtrace)
    return [] unless backtrace.is_a?(Array)
    
    backtrace.map do |frame|
      if frame.is_a?(String)
        # Parse Ruby backtrace string: "app/models/user.rb:42:in `save'"
        match = frame.match(/^(.+):(\d+):in `(.+)'$/)
        if match
          {
            'file' => match[1],
            'line' => match[2].to_i,
            'function' => match[3],
            'in_app' => in_app?(match[1])
          }
        else
          { 'file' => frame, 'line' => 0, 'function' => '', 'in_app' => false }
        end
      else
        frame.merge('in_app' => in_app?(frame['file']))
      end
    end
  end
  
  def in_app?(file_path)
    return false if file_path.nil?
    file_path.start_with?('app/', 'lib/') && !file_path.include?('/vendor/')
  end
  
  def extract_file_path
    first_frame = @payload[:backtrace]&.first
    return nil unless first_frame
    
    if first_frame.is_a?(String)
      first_frame.match(/^(.+):\d+/)&.captures&.first
    else
      first_frame['file']
    end
  end
  
  def extract_line_number
    first_frame = @payload[:backtrace]&.first
    return nil unless first_frame
    
    if first_frame.is_a?(String)
      first_frame.match(/:(\d+):/)&.captures&.first&.to_i
    else
      first_frame['line']
    end
  end
  
  def extract_function_name
    first_frame = @payload[:backtrace]&.first
    return nil unless first_frame
    
    if first_frame.is_a?(String)
      first_frame.match(/in `(.+)'/)&.captures&.first
    else
      first_frame['function']
    end
  end
  
  def sanitize_params(params)
    # Remove sensitive keys
    sensitive_keys = %w[password password_confirmation token api_key secret credit_card cvv]
    
    params.transform_values.with_index do |value, key|
      if sensitive_keys.include?(key.to_s.downcase)
        '[FILTERED]'
      elsif value.is_a?(Hash)
        sanitize_params(value)
      else
        value
      end
    end
  end
  
  def parse_timestamp(timestamp)
    case timestamp
    when Time, DateTime then timestamp
    when String then Time.parse(timestamp)
    when Numeric then Time.at(timestamp)
    else nil
    end
  rescue
    nil
  end
  
  def broadcast_new_error(error_group, event)
    ErrorsChannel.broadcast_to(@project, {
      type: 'new_error',
      error_group: {
        id: error_group.id,
        error_class: error_group.error_class,
        message: error_group.short_message,
        event_count: error_group.event_count,
        last_seen_at: error_group.last_seen_at
      },
      event: {
        id: event.id,
        environment: event.environment,
        commit: event.commit
      }
    })
  end
  
  def maybe_notify(error_group, event)
    return unless error_group.notifications_enabled
    return if error_group.last_notified_at && error_group.last_notified_at > 5.minutes.ago
    
    SendNotificationJob.perform_later(error_group.id, event.id)
    error_group.update!(last_notified_at: Time.current)
  end
end

# app/services/fingerprint_generator.rb

class FingerprintGenerator
  def self.generate(payload)
    # Create a unique fingerprint based on error class and location
    components = [
      payload[:error_class] || payload.dig(:exception, :class),
      extract_file(payload),
      extract_function(payload),
      # Optionally include normalized message
      normalize_message(payload[:message] || payload.dig(:exception, :message))
    ].compact
    
    Digest::SHA256.hexdigest(components.join('|'))[0..15]
  end
  
  def self.extract_file(payload)
    backtrace = payload[:backtrace] || payload.dig(:exception, :backtrace) || []
    first_frame = backtrace.first
    
    if first_frame.is_a?(String)
      first_frame.match(/^(.+):\d+/)&.captures&.first
    elsif first_frame.is_a?(Hash)
      first_frame['file']
    end
  end
  
  def self.extract_function(payload)
    backtrace = payload[:backtrace] || payload.dig(:exception, :backtrace) || []
    first_frame = backtrace.first
    
    if first_frame.is_a?(String)
      first_frame.match(/in `(.+)'/)&.captures&.first
    elsif first_frame.is_a?(Hash)
      first_frame['function']
    end
  end
  
  def self.normalize_message(message)
    return nil unless message
    
    # Remove dynamic parts from message
    message
      .gsub(/\b[0-9a-f]{8,}\b/i, 'ID')     # Hex IDs
      .gsub(/\b\d+\b/, 'N')                  # Numbers
      .gsub(/"[^"]*"/, '"..."')              # Quoted strings
      .gsub(/'[^']*'/, "'...'")              # Single quoted strings
      .truncate(200)
  end
end
```

---

## API Controllers

```ruby
# app/controllers/api/v1/base_controller.rb

module Api
  module V1
    class BaseController < ActionController::API
      before_action :authenticate!
      before_action :check_feature_access!
      
      attr_reader :current_project, :key_info
      
      private
      
      def authenticate!
        raw_key = extract_api_key
        @key_info = PlatformClient.validate_key(raw_key)
        
        unless @key_info[:valid]
          render json: { error: 'Invalid API key' }, status: :unauthorized
          return
        end
        
        @current_project = Project.find_or_create_for_platform!(
          platform_project_id: @key_info[:project_id],
          name: @key_info[:project_name],
          environment: @key_info[:environment]
        )
      end
      
      def check_feature_access!
        unless @key_info.dig(:features, :reflex)
          render json: { 
            error: 'Reflex is not included in your plan',
            upgrade_url: 'https://brainzlab.ai/pricing'
          }, status: :forbidden
        end
      end
      
      def extract_api_key
        auth_header = request.headers['Authorization']
        return auth_header.sub(/^Bearer\s+/, '') if auth_header&.start_with?('Bearer ')
        request.headers['X-API-Key'] || params[:api_key]
      end
      
      def track_usage!(count = 1)
        PlatformClient.track_usage(
          project_id: @key_info[:project_id],
          product: 'reflex',
          metric: 'errors',
          count: count
        )
      end
    end
  end
end

# app/controllers/api/v1/events_controller.rb

module Api
  module V1
    class EventsController < BaseController
      # POST /api/v1/errors
      def create
        result = ErrorProcessor.new(
          project: current_project,
          payload: error_params.to_h
        ).process!
        
        track_usage!(1)
        
        render json: {
          id: result[:event].id,
          error_group_id: result[:error_group].id,
          fingerprint: result[:error_group].fingerprint
        }, status: :created
      end
      
      # POST /api/v1/errors/batch
      def batch
        errors = params[:errors] || params[:_json] || []
        results = []
        
        errors.each do |error_payload|
          result = ErrorProcessor.new(
            project: current_project,
            payload: error_payload.to_h
          ).process!
          
          results << {
            id: result[:event].id,
            error_group_id: result[:error_group].id
          }
        end
        
        track_usage!(results.size)
        
        render json: { processed: results.size, results: results }, status: :created
      end
      
      private
      
      def error_params
        params.permit(
          :error_class, :message, :timestamp, :environment, :commit, :branch,
          :release, :server_name, :host, :request_id,
          exception: [:class, :message, backtrace: []],
          backtrace: [],
          request: [:id, :method, :url, :path, :controller, :action, params: {}, headers: {}],
          user: [:id, :email, :name],
          context: {},
          tags: {},
          extra: {},
          breadcrumbs: []
        )
      end
    end
  end
end

# app/controllers/api/v1/errors_controller.rb

module Api
  module V1
    class ErrorsController < BaseController
      # GET /api/v1/errors
      def index
        errors = current_project.error_groups
        
        errors = errors.where(status: params[:status]) if params[:status]
        errors = errors.where(error_class: params[:error_class]) if params[:error_class]
        
        if params[:since]
          since = Time.parse(params[:since]) rescue nil
          errors = errors.where('last_seen_at >= ?', since) if since
        end
        
        errors = case params[:sort]
          when 'frequent' then errors.frequent
          when 'first_seen' then errors.order(first_seen_at: :desc)
          else errors.recent
        end
        
        errors = errors.limit(params[:limit] || 50)
        
        render json: { errors: errors.as_json(include_stats: true) }
      end
      
      # GET /api/v1/errors/:id
      def show
        error = current_project.error_groups.find(params[:id])
        events = error.events.recent.limit(10)
        
        render json: {
          error: error,
          recent_events: events
        }
      end
      
      # POST /api/v1/errors/:id/resolve
      def resolve
        error = current_project.error_groups.find(params[:id])
        error.resolve!
        
        render json: { resolved: true, error: error }
      end
      
      # POST /api/v1/errors/:id/ignore
      def ignore
        error = current_project.error_groups.find(params[:id])
        error.ignore!
        
        render json: { ignored: true, error: error }
      end
      
      # POST /api/v1/errors/:id/unresolve
      def unresolve
        error = current_project.error_groups.find(params[:id])
        error.unresolve!
        
        render json: { unresolved: true, error: error }
      end
    end
  end
end
```

---

## MCP Tools

```ruby
# app/services/mcp/server.rb

module Mcp
  class Server
    TOOLS = {
      'reflex_list' => Tools::ReflexList,
      'reflex_show' => Tools::ReflexShow,
      'reflex_resolve' => Tools::ReflexResolve,
      'reflex_ignore' => Tools::ReflexIgnore,
      'reflex_unresolve' => Tools::ReflexUnresolve,
      'reflex_stats' => Tools::ReflexStats,
      'reflex_search' => Tools::ReflexSearch,
    }.freeze

    def initialize(project)
      @project = project
    end

    def list_tools
      TOOLS.map do |name, klass|
        {
          name: name,
          description: klass::DESCRIPTION,
          inputSchema: klass::SCHEMA
        }
      end
    end

    def call_tool(name, arguments = {})
      tool_class = TOOLS[name]
      raise "Unknown tool: #{name}" unless tool_class
      tool_class.new(@project).call(arguments.symbolize_keys)
    end
  end
end

# app/services/mcp/tools/base.rb

module Mcp
  module Tools
    class Base
      def initialize(project)
        @project = project
      end

      def call(args)
        raise NotImplementedError
      end
    end
  end
end

# app/services/mcp/tools/reflex_list.rb

module Mcp
  module Tools
    class ReflexList < Base
      DESCRIPTION = "List errors. Can filter by status (unresolved, resolved, ignored) " \
        "and sort by recent or frequent."
      
      SCHEMA = {
        type: "object",
        properties: {
          status: { 
            type: "string", 
            enum: ["unresolved", "resolved", "ignored", "all"],
            default: "unresolved",
            description: "Filter by status"
          },
          sort: {
            type: "string",
            enum: ["recent", "frequent"],
            default: "recent",
            description: "Sort order"
          },
          limit: { type: "integer", default: 20, description: "Max results" }
        }
      }.freeze

      def call(args)
        errors = @project.error_groups
        
        errors = case args[:status]
          when 'all' then errors
          when 'resolved' then errors.resolved
          when 'ignored' then errors.ignored
          else errors.unresolved
        end
        
        errors = args[:sort] == 'frequent' ? errors.frequent : errors.recent
        errors = errors.limit(args[:limit] || 20)
        
        {
          errors: errors.map { |e| format_error(e) },
          count: errors.size
        }
      end
      
      private
      
      def format_error(error)
        {
          id: error.id,
          error_class: error.error_class,
          message: error.short_message,
          location: error.location,
          status: error.status,
          event_count: error.event_count,
          first_seen: error.first_seen_at,
          last_seen: error.last_seen_at,
          last_commit: error.last_commit
        }
      end
    end
  end
end

# app/services/mcp/tools/reflex_show.rb

module Mcp
  module Tools
    class ReflexShow < Base
      DESCRIPTION = "Get details of a specific error including recent occurrences and backtrace."
      
      SCHEMA = {
        type: "object",
        properties: {
          error_id: { type: "string", description: "Error group ID" }
        },
        required: ["error_id"]
      }.freeze

      def call(args)
        error = @project.error_groups.find(args[:error_id])
        events = error.events.recent.limit(5)
        
        {
          error: {
            id: error.id,
            error_class: error.error_class,
            message: error.message,
            location: error.location,
            file_path: error.file_path,
            line_number: error.line_number,
            function_name: error.function_name,
            status: error.status,
            event_count: error.event_count,
            first_seen: error.first_seen_at,
            last_seen: error.last_seen_at
          },
          recent_events: events.map { |e| format_event(e) }
        }
      rescue ActiveRecord::RecordNotFound
        { error: "Error not found" }
      end
      
      private
      
      def format_event(event)
        {
          id: event.id,
          occurred_at: event.occurred_at,
          environment: event.environment,
          commit: event.commit,
          user_id: event.user_id,
          request_path: event.request_path,
          backtrace: event.app_backtrace.first(5)
        }
      end
    end
  end
end

# app/services/mcp/tools/reflex_resolve.rb

module Mcp
  module Tools
    class ReflexResolve < Base
      DESCRIPTION = "Mark an error as resolved."
      
      SCHEMA = {
        type: "object",
        properties: {
          error_id: { type: "string", description: "Error group ID" }
        },
        required: ["error_id"]
      }.freeze

      def call(args)
        error = @project.error_groups.find(args[:error_id])
        error.resolve!
        
        { resolved: true, error_id: error.id, error_class: error.error_class }
      rescue ActiveRecord::RecordNotFound
        { error: "Error not found" }
      end
    end
  end
end

# app/services/mcp/tools/reflex_ignore.rb

module Mcp
  module Tools
    class ReflexIgnore < Base
      DESCRIPTION = "Ignore an error. It won't appear in the unresolved list."
      
      SCHEMA = {
        type: "object",
        properties: {
          error_id: { type: "string", description: "Error group ID" }
        },
        required: ["error_id"]
      }.freeze

      def call(args)
        error = @project.error_groups.find(args[:error_id])
        error.ignore!
        
        { ignored: true, error_id: error.id, error_class: error.error_class }
      rescue ActiveRecord::RecordNotFound
        { error: "Error not found" }
      end
    end
  end
end

# app/services/mcp/tools/reflex_unresolve.rb

module Mcp
  module Tools
    class ReflexUnresolve < Base
      DESCRIPTION = "Mark a resolved error as unresolved again."
      
      SCHEMA = {
        type: "object",
        properties: {
          error_id: { type: "string", description: "Error group ID" }
        },
        required: ["error_id"]
      }.freeze

      def call(args)
        error = @project.error_groups.find(args[:error_id])
        error.unresolve!
        
        { unresolved: true, error_id: error.id, error_class: error.error_class }
      rescue ActiveRecord::RecordNotFound
        { error: "Error not found" }
      end
    end
  end
end

# app/services/mcp/tools/reflex_stats.rb

module Mcp
  module Tools
    class ReflexStats < Base
      DESCRIPTION = "Get error statistics - counts by status, top errors, trends."
      
      SCHEMA = {
        type: "object",
        properties: {
          since: { type: "string", default: "24h", description: "Time period (1h, 24h, 7d)" }
        }
      }.freeze

      def call(args)
        since = parse_since(args[:since] || '24h')
        
        errors = @project.error_groups
        events = @project.error_events.where('occurred_at >= ?', since)
        
        {
          total_errors: errors.count,
          unresolved: errors.unresolved.count,
          resolved: errors.resolved.count,
          ignored: errors.ignored.count,
          
          events_in_period: events.count,
          
          top_errors: errors.unresolved.frequent.limit(5).map { |e|
            { error_class: e.error_class, message: e.short_message, count: e.event_count }
          },
          
          by_environment: events.group(:environment).count,
          by_hour: events.group_by_hour(:occurred_at).count
        }
      end
      
      private
      
      def parse_since(value)
        case value
        when /^(\d+)h$/ then $1.to_i.hours.ago
        when /^(\d+)d$/ then $1.to_i.days.ago
        when /^(\d+)w$/ then $1.to_i.weeks.ago
        else 24.hours.ago
        end
      end
    end
  end
end

# app/services/mcp/tools/reflex_search.rb

module Mcp
  module Tools
    class ReflexSearch < Base
      DESCRIPTION = "Search errors by class name, message, or other criteria."
      
      SCHEMA = {
        type: "object",
        properties: {
          query: { type: "string", description: "Search query" },
          error_class: { type: "string", description: "Filter by error class" },
          user_id: { type: "string", description: "Filter by user ID" },
          commit: { type: "string", description: "Filter by commit" },
          since: { type: "string", description: "Time period (1h, 24h, 7d)" }
        }
      }.freeze

      def call(args)
        errors = @project.error_groups
        
        if args[:query]
          errors = errors.where("error_class ILIKE ? OR message ILIKE ?", 
            "%#{args[:query]}%", "%#{args[:query]}%")
        end
        
        errors = errors.where(error_class: args[:error_class]) if args[:error_class]
        
        if args[:since]
          since = parse_since(args[:since])
          errors = errors.where('last_seen_at >= ?', since)
        end
        
        # If filtering by user or commit, need to check events
        if args[:user_id] || args[:commit]
          event_scope = @project.error_events
          event_scope = event_scope.where(user_id: args[:user_id]) if args[:user_id]
          event_scope = event_scope.where(commit: args[:commit]) if args[:commit]
          
          error_ids = event_scope.distinct.pluck(:error_group_id)
          errors = errors.where(id: error_ids)
        end
        
        {
          errors: errors.recent.limit(20).map { |e|
            { id: e.id, error_class: e.error_class, message: e.short_message, event_count: e.event_count }
          },
          count: errors.count
        }
      end
      
      private
      
      def parse_since(value)
        case value
        when /^(\d+)h$/ then $1.to_i.hours.ago
        when /^(\d+)d$/ then $1.to_i.days.ago
        else 24.hours.ago
        end
      end
    end
  end
end
```

---

## Routes

```ruby
# config/routes.rb

Rails.application.routes.draw do
  # API
  namespace :api do
    namespace :v1 do
      # Ingest errors
      post 'errors', to: 'events#create'
      post 'errors/batch', to: 'events#batch'
      
      # Query errors
      get 'errors', to: 'errors#index'
      get 'errors/:id', to: 'errors#show'
      post 'errors/:id/resolve', to: 'errors#resolve'
      post 'errors/:id/ignore', to: 'errors#ignore'
      post 'errors/:id/unresolve', to: 'errors#unresolve'
    end
  end
  
  # MCP Server
  namespace :mcp do
    get 'tools', to: 'tools#index'
    post 'tools/:name', to: 'tools#call'
    post 'rpc', to: 'tools#rpc'
  end
  
  # SSO from Platform
  get 'auth/sso', to: 'sso#callback'
  
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
  
  # Health
  get 'up', to: ->(_) { [200, {}, ['ok']] }
  
  # WebSocket
  mount ActionCable.server => '/cable'
  
  root 'dashboard/errors#index'
end
```

---

## Dashboard Views

```erb
<%# app/views/layouts/dashboard.html.erb %>

<!DOCTYPE html>
<html lang="en" class="h-full bg-stone-50">
<head>
  <title>Reflex - Error Tracking</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <%= csrf_meta_tags %>
  <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
  <%= javascript_include_tag "application", "data-turbo-track": "reload", type: "module" %>
</head>
<body class="h-full font-sans antialiased text-stone-900">
  <div class="min-h-full">
    <header class="border-b border-stone-200 bg-white">
      <div class="mx-auto max-w-7xl px-6">
        <div class="flex h-14 items-center justify-between">
          <div class="flex items-center gap-4">
            <a href="https://brainzlab.ai/dashboard" class="text-stone-400 hover:text-stone-600">
              ← Brainz Lab
            </a>
            <span class="text-stone-300">|</span>
            <%= link_to dashboard_root_path, class: "flex items-center gap-2 font-semibold" do %>
              <span class="text-red-500">⚡</span>
              <span>Reflex</span>
            <% end %>
          </div>
          
          <div class="flex items-center gap-4 text-sm">
            <span class="text-stone-500"><%= session[:project_id] %></span>
          </div>
        </div>
      </div>
    </header>
    
    <main class="mx-auto max-w-7xl px-6 py-8">
      <%= yield %>
    </main>
  </div>
</body>
</html>

<%# app/views/dashboard/errors/index.html.erb %>

<div class="space-y-6" data-controller="live-errors">
  <!-- Header -->
  <div class="flex justify-between items-center">
    <h1 class="text-2xl font-bold">Errors</h1>
    
    <div class="flex items-center gap-4">
      <!-- Filters -->
      <div class="flex gap-2">
        <% %w[unresolved resolved ignored].each do |status| %>
          <%= link_to status.capitalize, 
              dashboard_errors_path(status: status),
              class: "px-3 py-1.5 text-sm font-medium rounded-lg #{params[:status] == status || (params[:status].nil? && status == 'unresolved') ? 'bg-stone-900 text-white' : 'bg-white border border-stone-200 text-stone-600 hover:bg-stone-50'}" %>
        <% end %>
      </div>
      
      <!-- Live toggle -->
      <label class="flex items-center gap-2 text-sm">
        <input type="checkbox" data-action="change->live-errors#toggle" class="rounded">
        <span class="text-stone-600">Live</span>
      </label>
    </div>
  </div>
  
  <!-- Stats bar -->
  <div class="flex gap-6 text-sm">
    <div class="flex items-center gap-2">
      <span class="w-2 h-2 rounded-full bg-red-500"></span>
      <span class="text-stone-600"><%= @stats[:unresolved] %> unresolved</span>
    </div>
    <div class="flex items-center gap-2">
      <span class="w-2 h-2 rounded-full bg-green-500"></span>
      <span class="text-stone-600"><%= @stats[:resolved] %> resolved</span>
    </div>
    <div class="text-stone-400">
      <%= @stats[:events_today] %> events today
    </div>
  </div>
  
  <!-- Error list -->
  <div class="bg-white rounded-xl border border-stone-200 divide-y divide-stone-100" data-live-errors-target="container">
    <% @errors.each do |error| %>
      <%= render 'error_row', error: error %>
    <% end %>
    
    <% if @errors.empty? %>
      <div class="p-12 text-center">
        <span class="text-4xl">🎉</span>
        <p class="mt-4 text-stone-500">No errors! Everything is running smoothly.</p>
      </div>
    <% end %>
  </div>
</div>

<%# app/views/dashboard/errors/_error_row.html.erb %>

<%= link_to dashboard_error_path(error), class: "block hover:bg-stone-50 transition" do %>
  <div class="flex items-start gap-4 p-4">
    <!-- Status indicator -->
    <div class="mt-1">
      <% case error.status %>
      <% when 'unresolved' %>
        <span class="w-2 h-2 rounded-full bg-red-500 block"></span>
      <% when 'resolved' %>
        <span class="w-2 h-2 rounded-full bg-green-500 block"></span>
      <% when 'ignored' %>
        <span class="w-2 h-2 rounded-full bg-stone-300 block"></span>
      <% end %>
    </div>
    
    <!-- Error info -->
    <div class="flex-1 min-w-0">
      <div class="flex items-center gap-2">
        <span class="font-medium text-red-600"><%= error.error_class %></span>
        <span class="text-stone-400 text-sm"><%= error.location %></span>
      </div>
      <p class="text-stone-600 truncate mt-1"><%= error.short_message %></p>
      <div class="flex items-center gap-4 mt-2 text-xs text-stone-400">
        <span><%= error.event_count %> events</span>
        <span>Last seen <%= time_ago_in_words(error.last_seen_at) %> ago</span>
        <% if error.last_commit %>
          <span class="font-mono bg-stone-100 px-1.5 py-0.5 rounded"><%= error.last_commit[0..6] %></span>
        <% end %>
      </div>
    </div>
    
    <!-- Sparkline / trend could go here -->
    <div class="text-right">
      <span class="text-lg font-semibold text-stone-400"><%= error.event_count %></span>
    </div>
  </div>
<% end %>

<%# app/views/dashboard/errors/show.html.erb %>

<div class="space-y-6">
  <!-- Header -->
  <div class="flex justify-between items-start">
    <div>
      <div class="flex items-center gap-3">
        <%= link_to '← Back', dashboard_errors_path, class: 'text-stone-400 hover:text-stone-600' %>
        <span class="status-badge status-<%= @error.status %>"><%= @error.status %></span>
      </div>
      <h1 class="text-2xl font-bold text-red-600 mt-2"><%= @error.error_class %></h1>
      <p class="text-stone-600 mt-1"><%= @error.message %></p>
      <p class="text-sm text-stone-400 mt-2"><%= @error.location %></p>
    </div>
    
    <div class="flex gap-2">
      <% if @error.status == 'unresolved' %>
        <%= button_to 'Resolve', resolve_dashboard_error_path(@error), 
            method: :post, class: 'px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700' %>
        <%= button_to 'Ignore', ignore_dashboard_error_path(@error),
            method: :post, class: 'px-4 py-2 bg-stone-200 text-stone-700 rounded-lg hover:bg-stone-300' %>
      <% else %>
        <%= button_to 'Unresolve', unresolve_dashboard_error_path(@error),
            method: :post, class: 'px-4 py-2 bg-stone-200 text-stone-700 rounded-lg hover:bg-stone-300' %>
      <% end %>
    </div>
  </div>
  
  <!-- Stats -->
  <div class="grid grid-cols-4 gap-4">
    <div class="bg-white rounded-lg border border-stone-200 p-4">
      <p class="text-sm text-stone-500">Total Events</p>
      <p class="text-2xl font-bold"><%= @error.event_count %></p>
    </div>
    <div class="bg-white rounded-lg border border-stone-200 p-4">
      <p class="text-sm text-stone-500">First Seen</p>
      <p class="text-lg font-medium"><%= @error.first_seen_at.strftime('%b %d, %H:%M') %></p>
    </div>
    <div class="bg-white rounded-lg border border-stone-200 p-4">
      <p class="text-sm text-stone-500">Last Seen</p>
      <p class="text-lg font-medium"><%= time_ago_in_words(@error.last_seen_at) %> ago</p>
    </div>
    <div class="bg-white rounded-lg border border-stone-200 p-4">
      <p class="text-sm text-stone-500">Last Commit</p>
      <p class="text-lg font-mono"><%= @error.last_commit&.slice(0, 7) || '—' %></p>
    </div>
  </div>
  
  <!-- Latest Event -->
  <div class="bg-white rounded-xl border border-stone-200">
    <div class="p-4 border-b border-stone-100">
      <h2 class="font-semibold">Latest Occurrence</h2>
    </div>
    
    <% if @latest_event %>
      <div class="p-4">
        <!-- Backtrace -->
        <div class="bg-stone-900 rounded-lg p-4 overflow-x-auto">
          <pre class="text-sm font-mono text-stone-100"><% @latest_event.app_backtrace.each do |frame| %>
<span class="text-stone-400"><%= frame[:file] %>:<%= frame[:line] %></span> in <span class="text-red-400"><%= frame[:function] %></span>
<% end %></pre>
        </div>
        
        <!-- Context -->
        <div class="mt-4 grid grid-cols-2 gap-4 text-sm">
          <div>
            <h3 class="font-medium mb-2">Request</h3>
            <dl class="space-y-1 text-stone-600">
              <div><dt class="inline text-stone-400">Method:</dt> <%= @latest_event.request_method %></div>
              <div><dt class="inline text-stone-400">Path:</dt> <%= @latest_event.request_path %></div>
              <div><dt class="inline text-stone-400">ID:</dt> <span class="font-mono"><%= @latest_event.request_id %></span></div>
            </dl>
          </div>
          
          <div>
            <h3 class="font-medium mb-2">Context</h3>
            <dl class="space-y-1 text-stone-600">
              <div><dt class="inline text-stone-400">Environment:</dt> <%= @latest_event.environment %></div>
              <div><dt class="inline text-stone-400">Commit:</dt> <span class="font-mono"><%= @latest_event.commit&.slice(0, 7) %></span></div>
              <div><dt class="inline text-stone-400">User:</dt> <%= @latest_event.user_id || '—' %></div>
            </dl>
          </div>
        </div>
        
        <% if @latest_event.context.present? %>
          <div class="mt-4">
            <h3 class="font-medium mb-2">Custom Context</h3>
            <pre class="bg-stone-50 rounded-lg p-3 text-sm font-mono overflow-x-auto"><%= JSON.pretty_generate(@latest_event.context) %></pre>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>
  
  <!-- Event History -->
  <div class="bg-white rounded-xl border border-stone-200">
    <div class="p-4 border-b border-stone-100">
      <h2 class="font-semibold">Recent Events</h2>
    </div>
    
    <div class="divide-y divide-stone-100">
      <% @events.each do |event| %>
        <div class="flex items-center gap-4 p-4 text-sm">
          <span class="text-stone-400"><%= event.occurred_at.strftime('%b %d, %H:%M:%S') %></span>
          <span class="px-2 py-0.5 bg-stone-100 rounded text-xs"><%= event.environment %></span>
          <span class="font-mono text-xs text-stone-500"><%= event.commit&.slice(0, 7) %></span>
          <span class="text-stone-500"><%= event.user_id || 'anonymous' %></span>
          <span class="text-stone-400 truncate"><%= event.request_path %></span>
        </div>
      <% end %>
    </div>
  </div>
</div>
```

---

## Tailwind Styles

```css
/* app/assets/stylesheets/application.tailwind.css */

@tailwind base;
@tailwind components;
@tailwind utilities;

@layer components {
  .status-badge {
    @apply px-2 py-0.5 text-xs font-medium rounded-full uppercase tracking-wide;
  }
  
  .status-unresolved {
    @apply bg-red-100 text-red-700;
  }
  
  .status-resolved {
    @apply bg-green-100 text-green-700;
  }
  
  .status-ignored {
    @apply bg-stone-100 text-stone-600;
  }
  
  .status-muted {
    @apply bg-yellow-100 text-yellow-700;
  }
}
```

---

## Stimulus Controllers

```javascript
// app/javascript/controllers/live_errors_controller.js

import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["container"]
  
  toggle(event) {
    event.target.checked ? this.start() : this.stop()
  }
  
  start() {
    this.subscription = createConsumer().subscriptions.create(
      { channel: "ErrorsChannel" },
      {
        received: (data) => {
          if (data.type === 'new_error') {
            this.prependError(data)
          }
        }
      }
    )
  }
  
  stop() {
    this.subscription?.unsubscribe()
  }
  
  prependError(data) {
    const error = data.error_group
    const html = `
      <a href="/dashboard/errors/${error.id}" class="block hover:bg-red-50 transition border-b border-stone-100 bg-red-50/50">
        <div class="flex items-start gap-4 p-4">
          <div class="mt-1">
            <span class="w-2 h-2 rounded-full bg-red-500 block animate-pulse"></span>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <span class="font-medium text-red-600">${error.error_class}</span>
              <span class="text-xs bg-red-100 text-red-600 px-1.5 py-0.5 rounded">NEW</span>
            </div>
            <p class="text-stone-600 truncate mt-1">${error.message || ''}</p>
            <div class="flex items-center gap-4 mt-2 text-xs text-stone-400">
              <span>${error.event_count} events</span>
              <span>Just now</span>
            </div>
          </div>
        </div>
      </a>
    `
    this.containerTarget.insertAdjacentHTML('afterbegin', html)
  }
  
  disconnect() {
    this.stop()
  }
}
```

---

## SDK Integration (in brainzlab-sdk gem)

```ruby
# lib/brainzlab/reflex.rb

module BrainzLab
  module Reflex
    class << self
      def capture(exception, context: {}, user: nil, tags: {}, extra: {})
        return unless BrainzLab.config.secret_key
        
        payload = build_payload(exception, context, user, tags, extra)
        send_to_api(payload)
      end
      
      def capture_message(message, level: 'error', context: {}, user: nil, tags: {})
        return unless BrainzLab.config.secret_key
        
        payload = {
          error_class: 'Message',
          message: message,
          level: level,
          context: context,
          user: user,
          tags: tags,
          timestamp: Time.now.utc.iso8601,
          environment: BrainzLab.config.environment,
          commit: BrainzLab.config.commit,
          branch: BrainzLab.config.branch
        }
        
        send_to_api(payload)
      end
      
      private
      
      def build_payload(exception, context, user, tags, extra)
        {
          error_class: exception.class.name,
          message: exception.message,
          backtrace: exception.backtrace || [],
          
          context: context.merge(current_context),
          user: user || current_user,
          tags: tags,
          extra: extra,
          
          timestamp: Time.now.utc.iso8601,
          environment: BrainzLab.config.environment,
          commit: BrainzLab.config.commit,
          branch: BrainzLab.config.branch,
          server_name: BrainzLab.config.host,
          
          request: current_request,
          breadcrumbs: current_breadcrumbs
        }
      end
      
      def send_to_api(payload)
        uri = URI("#{BrainzLab.config.reflex_url}/api/v1/errors")
        
        Thread.new do
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          
          request = Net::HTTP::Post.new(uri.path)
          request['Content-Type'] = 'application/json'
          request['Authorization'] = "Bearer #{BrainzLab.config.secret_key}"
          request.body = payload.to_json
          
          http.request(request)
        rescue => e
          warn "[Reflex] Failed to send error: #{e.message}"
        end
      end
      
      def current_context
        Thread.current[:brainzlab_context] || {}
      end
      
      def current_user
        Thread.current[:brainzlab_user]
      end
      
      def current_request
        Thread.current[:brainzlab_request]
      end
      
      def current_breadcrumbs
        Thread.current[:brainzlab_breadcrumbs] || []
      end
    end
    
    # Rails integration
    class Middleware
      def initialize(app)
        @app = app
      end
      
      def call(env)
        # Capture request context
        request = ActionDispatch::Request.new(env)
        Thread.current[:brainzlab_request] = {
          id: request.request_id,
          method: request.method,
          url: request.url,
          path: request.path,
          params: request.filtered_parameters,
          headers: extract_headers(request)
        }
        
        @app.call(env)
      rescue Exception => e
        BrainzLab::Reflex.capture(e)
        raise
      ensure
        Thread.current[:brainzlab_request] = nil
      end
      
      private
      
      def extract_headers(request)
        {
          'User-Agent' => request.user_agent,
          'Referer' => request.referer,
          'Accept-Language' => request.headers['Accept-Language']
        }.compact
      end
    end
    
    class Railtie < Rails::Railtie
      initializer 'reflex.middleware' do |app|
        app.middleware.use BrainzLab::Reflex::Middleware
      end
    end
  end
end
```

---

## Docker Compose

```yaml
# docker-compose.yml

services:
  web:
    build: .
    ports: ["3000:3000"]
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/reflex
      REDIS_URL: redis://redis:6379/0
      PLATFORM_URL: http://platform:3000
      SERVICE_TOKEN: dev-service-token
      SECRET_KEY_BASE: dev-secret
    depends_on: [db, redis]
    volumes: [".:/rails"]

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: reflex
      POSTGRES_PASSWORD: postgres
    volumes: [pgdata:/var/lib/postgresql/data]

  redis:
    image: redis:7-alpine

volumes:
  pgdata:
```

---

## MCP Tools Summary

| Tool | Description |
|------|-------------|
| `reflex_list` | List errors with filters (status, sort) |
| `reflex_show` | Get error details + backtrace |
| `reflex_resolve` | Mark error as resolved |
| `reflex_ignore` | Ignore an error |
| `reflex_unresolve` | Reopen a resolved error |
| `reflex_stats` | Error statistics and trends |
| `reflex_search` | Search by class, user, commit |

---

## AI Conversation Examples

```
User: What errors do we have?

AI: [calls reflex_list(status: "unresolved")]
    You have 3 unresolved errors:
    1. NoMethodError in UsersController#create (42 events)
    2. TimeoutError in PaymentService (15 events)
    3. ActiveRecord::RecordNotFound (8 events)

User: Show me the payment error

AI: [calls reflex_show(error_id: "xxx")]
    TimeoutError in PaymentService#charge
    
    File: app/services/payment_service.rb:45
    Message: "execution expired"
    
    Last occurred: 5 minutes ago
    First seen: 2 days ago
    Total events: 15
    
    Recent backtrace:
    - app/services/payment_service.rb:45 in `charge`
    - app/controllers/orders_controller.rb:23 in `create`

User: Resolve it, we fixed it in the last deploy

AI: [calls reflex_resolve(error_id: "xxx")]
    ✓ Resolved TimeoutError in PaymentService
```

---

## Success Criteria

1. ✅ Errors ingested via API
2. ✅ Errors grouped by fingerprint
3. ✅ Dashboard shows error list with status
4. ✅ Error detail view with backtrace
5. ✅ Resolve/ignore/unresolve actions
6. ✅ Real-time error streaming
7. ✅ MCP tools for AI
8. ✅ SDK integration with Rails

---

**Domain:** reflex.brainzlab.ai

**Tagline:** *"Instant reaction to errors"*
