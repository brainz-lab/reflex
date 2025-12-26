ENV["RAILS_ENV"] ||= "test"
ENV["BRAINZLAB_SDK_ENABLED"] = "false"  # Disable SDK during tests to avoid database issues
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Helper to create a valid project
    def create_project(platform_project_id: "prj_#{SecureRandom.hex(8)}", name: "Test Project", environment: "live")
      Project.create!(
        platform_project_id: platform_project_id,
        name: name,
        environment: environment
      )
    end

    # Helper to create a valid error group
    def create_error_group(project:, **attrs)
      defaults = {
        fingerprint: SecureRandom.hex(8),
        error_class: "NoMethodError",
        message: "undefined method 'foo' for nil:NilClass",
        file_path: "app/models/user.rb",
        line_number: 42,
        function_name: "full_name",
        status: "unresolved",
        first_seen_at: Time.current,
        last_seen_at: Time.current
      }

      project.error_groups.create!(defaults.merge(attrs))
    end

    # Helper to create a valid error event
    def create_error_event(error_group:, **attrs)
      defaults = {
        project: error_group.project,
        error_class: error_group.error_class,
        message: error_group.message,
        backtrace: [
          {
            "file" => "app/models/user.rb",
            "line" => 42,
            "function" => "full_name",
            "in_app" => true
          }
        ],
        environment: "production",
        occurred_at: Time.current
      }

      error_group.events.create!(defaults.merge(attrs))
    end

    # Helper for error payload
    def sample_error_payload(overrides = {})
      {
        error_class: "NoMethodError",
        message: "undefined method 'foo' for nil:NilClass",
        backtrace: [
          "app/models/user.rb:42:in `full_name'",
          "app/controllers/users_controller.rb:23:in `show'"
        ],
        environment: "production",
        commit: "abc123",
        request: {
          method: "POST",
          path: "/users",
          params: { name: "John" }
        },
        user: {
          id: "user_123",
          email: "john@example.com"
        },
        context: {},
        tags: {},
        timestamp: Time.current.iso8601
      }.deep_merge(overrides)
    end
  end
end

# Stub PlatformClient for tests
class PlatformClient
  def self.validate_key(api_key)
    if api_key == "valid_key"
      {
        valid: true,
        project_id: "prj_test123",
        project_name: "Test Project",
        environment: "live",
        features: { reflex: true }
      }
    elsif api_key&.start_with?("rfx_")
      nil # Will be handled by find_project_by_api_key
    else
      { valid: false }
    end
  end

  def self.track_usage(project_id:, product:, metric:, count:)
    # Stub - do nothing in tests
    true
  end

  def self.get_project_config(platform_project_id:)
    {
      name: "Test Project",
      environment: "live"
    }
  end
end
