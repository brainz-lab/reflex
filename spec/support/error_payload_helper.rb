# frozen_string_literal: true

module ErrorPayloadHelper
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

RSpec.configure do |config|
  config.include ErrorPayloadHelper
end
