module Dashboard
  class ProjectsController < BaseController
    skip_before_action :set_project, only: [:index, :new, :create]
    skip_before_action :authenticate!, only: [:index, :new, :create], if: -> { Rails.env.development? }
    before_action :set_project, only: [:show, :setup, :mcp_setup, :analytics, :edit, :update]

    def index
      if Rails.env.development?
        # In dev, show all projects
        @projects = Project.order(created_at: :desc)
      elsif @api_key_info && @api_key_info[:project_id]
        # In production, show only the project for this API key
        project = Project.find_or_create_for_platform!(
          platform_project_id: @api_key_info[:project_id],
          name: @api_key_info[:project_name],
          environment: @api_key_info[:environment] || 'live'
        )
        @projects = [project]
      else
        redirect_to new_dashboard_project_path
      end
    end

    def show
      redirect_to dashboard_project_errors_path(@project)
    end

    def new
      @project = Project.new
    end

    def create
      if Rails.env.development?
        # In dev, create project directly
        @project = Project.new(
          name: params[:project]&.[](:name) || params[:name],
          environment: params[:project]&.[](:environment) || 'development',
          platform_project_id: SecureRandom.uuid
        )

        if @project.name.blank?
          flash.now[:alert] = 'Please enter a project name'
          return render :new, status: :unprocessable_entity
        end

        if @project.save
          # Set a dev API key in session
          session[:api_key] = "dev_#{@project.id}"
          redirect_to dashboard_project_errors_path(@project), notice: "Created #{@project.name}"
        else
          flash.now[:alert] = @project.errors.full_messages.join(', ')
          render :new, status: :unprocessable_entity
        end
      else
        # In production, require API key from Platform
        api_key = params[:api_key]&.strip

        if api_key.blank?
          flash.now[:alert] = 'Please enter an API key'
          @project = Project.new
          return render :new, status: :unprocessable_entity
        end

        key_info = PlatformClient.validate_key(api_key)

        unless key_info[:valid]
          flash.now[:alert] = 'Invalid API key. Please check and try again.'
          @project = Project.new
          return render :new, status: :unprocessable_entity
        end

        project = Project.find_or_create_for_platform!(
          platform_project_id: key_info[:project_id],
          name: key_info[:project_name],
          environment: key_info[:environment] || 'live'
        )

        session[:api_key] = api_key
        redirect_to dashboard_project_errors_path(project), notice: "Connected to #{project.name}"
      end
    end

    def setup
    end

    def mcp_setup
    end

    def edit
    end

    def update
      if @project.update(project_params)
        redirect_to edit_dashboard_project_path(@project), notice: 'Settings saved successfully'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def analytics
      @period = params[:period] || '7d'
      @start_date = period_start_date(@period)

      # Overview stats
      @stats = {
        total_errors: @project.error_groups.count,
        unresolved: @project.error_groups.unresolved.count,
        resolved: @project.error_groups.resolved.count,
        ignored: @project.error_groups.ignored.count,
        total_events: @project.error_events.count,
        events_in_period: @project.error_events.where('occurred_at >= ?', @start_date).count
      }

      # Events over time (for chart)
      @events_by_day = @project.error_events
        .where('occurred_at >= ?', @start_date)
        .group("DATE(occurred_at)")
        .order("DATE(occurred_at)")
        .count

      # Fill in missing days with zeros
      @chart_data = fill_missing_days(@events_by_day, @start_date)

      # Top errors by frequency
      @top_errors = @project.error_groups
        .where('last_seen_at >= ?', @start_date)
        .order(event_count: :desc)
        .limit(5)

      # Errors by class (for chart) - sum event_count per error class
      @errors_by_class = @project.error_groups
        .where('last_seen_at >= ?', @start_date)
        .group(:error_class)
        .order('sum_event_count DESC')
        .limit(8)
        .sum(:event_count)
        .map { |error_class, count| { error_class: error_class, count: count } }

      # Recent errors (new in period)
      @new_errors = @project.error_groups
        .where('first_seen_at >= ?', @start_date)
        .order(first_seen_at: :desc)
        .limit(5)

      # Errors by status
      @status_breakdown = @project.error_groups.group(:status).count

      # Events by environment
      @env_breakdown = @project.error_events
        .where('occurred_at >= ?', @start_date)
        .group(:environment)
        .count

      # Events by hour (for heatmap-style display)
      @events_by_hour = @project.error_events
        .where('occurred_at >= ?', @start_date)
        .group("EXTRACT(HOUR FROM occurred_at)::integer")
        .count
        .transform_keys(&:to_i)

      # Most affected users
      @affected_users = @project.error_events
        .where('occurred_at >= ?', @start_date)
        .where.not(user_id: nil)
        .group(:user_id, :user_email)
        .order('count_all DESC')
        .limit(5)
        .count

      # Errors by release/deploy
      @errors_by_release = @project.error_events
        .where('occurred_at >= ?', @start_date)
        .where.not(release: [nil, ''])
        .group(:release)
        .order('count_all DESC')
        .limit(8)
        .count

      # Errors by branch
      @errors_by_branch = @project.error_events
        .where('occurred_at >= ?', @start_date)
        .where.not(branch: [nil, ''])
        .group(:branch)
        .order('count_all DESC')
        .limit(5)
        .count

      # Errors by commit
      @errors_by_commit = @project.error_events
        .where('occurred_at >= ?', @start_date)
        .where.not(commit: [nil, ''])
        .group(:commit)
        .order('count_all DESC')
        .limit(8)
        .count

      # Errors by server/host
      @errors_by_server = @project.error_events
        .where('occurred_at >= ?', @start_date)
        .where.not(server_name: [nil, ''])
        .group(:server_name)
        .order('count_all DESC')
        .limit(5)
        .count
    end

    private

    def project_params
      params.require(:project).permit(:name, :environment, settings: {})
    end

    def period_start_date(period)
      case period
      when '24h' then 24.hours.ago
      when '7d' then 7.days.ago
      when '30d' then 30.days.ago
      when '90d' then 90.days.ago
      else 7.days.ago
      end
    end

    def fill_missing_days(data, start_date)
      result = []
      current = start_date.to_date
      today = Date.current

      while current <= today
        # Handle both Date keys and string keys
        count = data[current] || data[current.to_s] || 0
        result << {
          date: current.strftime('%b %d'),
          count: count
        }
        current += 1.day
      end

      result
    end
  end
end
