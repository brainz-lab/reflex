module Dashboard
  class ProjectsController < BaseController
    skip_before_action :set_project, only: [:index]
    before_action :set_project, only: [:show, :setup, :mcp_setup, :analytics]

    def index
      # Redirect to the project associated with the API key
      if @api_key_info && @api_key_info[:project_id]
        project = Project.find_or_create_for_platform!(
          platform_project_id: @api_key_info[:project_id],
          name: @api_key_info[:project_name],
          environment: @api_key_info[:environment] || 'live'
        )
        redirect_to dashboard_project_errors_path(project)
      else
        render 'dashboard/auth_required', status: :unauthorized
      end
    end

    def show
      redirect_to dashboard_project_errors_path(@project)
    end

    def setup
    end

    def mcp_setup
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
