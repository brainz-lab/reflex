require "test_helper"

class ErrorProcessorTest < ActiveSupport::TestCase
  test "creates error group and event" do
    project = create_project
    payload = sample_error_payload

    assert_difference [ "ErrorGroup.count", "ErrorEvent.count" ], 1 do
      processor = ErrorProcessor.new(project: project, payload: payload)
      result = processor.process!

      assert_not_nil result[:error_group]
      assert_not_nil result[:event]
    end
  end

  test "finds existing error group by fingerprint" do
    project = create_project
    payload = sample_error_payload

    # First occurrence
    processor1 = ErrorProcessor.new(project: project, payload: payload)
    result1 = processor1.process!

    # Second occurrence with same fingerprint
    assert_no_difference "ErrorGroup.count" do
      assert_difference "ErrorEvent.count", 1 do
        processor2 = ErrorProcessor.new(project: project, payload: payload)
        result2 = processor2.process!

        assert_equal result1[:error_group].id, result2[:error_group].id
      end
    end
  end

  test "updates error group occurrence stats" do
    project = create_project
    error_group = create_error_group(
      project: project,
      event_count: 5,
      last_seen_at: 2.hours.ago,
      last_commit: "old_commit"
    )

    # Mock fingerprint to match existing group
    FingerprintGenerator.stub :generate, error_group.fingerprint do
      payload = sample_error_payload(commit: "new_commit")
      processor = ErrorProcessor.new(project: project, payload: payload)
      processor.process!

      error_group.reload
      assert_equal 6, error_group.event_count
      assert_in_delta Time.current.to_i, error_group.last_seen_at.to_i, 1
      assert_equal "new_commit", error_group.last_commit
    end
  end

  test "unresolves resolved error on new occurrence" do
    project = create_project
    error_group = create_error_group(
      project: project,
      status: "resolved",
      resolved_at: 1.hour.ago
    )

    FingerprintGenerator.stub :generate, error_group.fingerprint do
      payload = sample_error_payload
      processor = ErrorProcessor.new(project: project, payload: payload)
      processor.process!

      error_group.reload
      assert_equal "unresolved", error_group.status
      assert_nil error_group.resolved_at
    end
  end

  test "extracts error class from payload" do
    project = create_project
    payload = sample_error_payload(error_class: "CustomError")

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    assert_equal "CustomError", result[:error_group].error_class
    assert_equal "CustomError", result[:event].error_class
  end

  test "extracts error class from exception hash" do
    project = create_project
    payload = {
      exception: {
        class: "CustomError",
        message: "Something went wrong"
      },
      backtrace: [ "app/models/user.rb:42:in `method'" ]
    }

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    assert_equal "CustomError", result[:error_group].error_class
  end

  test "defaults to UnknownError if no error class provided" do
    project = create_project
    payload = {
      message: "Something went wrong",
      backtrace: [ "app/models/user.rb:42:in `method'" ]
    }

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    assert_equal "UnknownError", result[:error_group].error_class
  end

  test "normalizes string backtrace to hash format" do
    project = create_project
    payload = sample_error_payload(
      backtrace: [
        "app/models/user.rb:42:in `full_name'",
        "app/controllers/users_controller.rb:23:in `show'"
      ]
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    backtrace = result[:event].backtrace
    assert_equal 2, backtrace.length
    assert_equal "app/models/user.rb", backtrace[0]["file"]
    assert_equal 42, backtrace[0]["line"]
    assert_equal "full_name", backtrace[0]["function"]
    assert backtrace[0]["in_app"]
  end

  test "marks gem frames as not in_app" do
    project = create_project
    payload = sample_error_payload(
      backtrace: [
        "app/models/user.rb:42:in `full_name'",
        "/gems/activerecord/lib/active_record.rb:100:in `save'"
      ]
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    backtrace = result[:event].backtrace
    assert backtrace[0]["in_app"]
    assert_not backtrace[1]["in_app"]
  end

  test "sanitizes sensitive parameters" do
    project = create_project
    payload = sample_error_payload(
      request: {
        params: {
          name: "John",
          password: "secret123",
          password_confirmation: "secret123",
          token: "api_token_123"
        }
      }
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    params = result[:event].request_params
    assert_equal "John", params["name"]
    assert_equal "[FILTERED]", params["password"]
    assert_equal "[FILTERED]", params["password_confirmation"]
    assert_equal "[FILTERED]", params["token"]
  end

  test "sanitizes nested sensitive parameters" do
    project = create_project
    payload = sample_error_payload(
      request: {
        params: {
          user: {
            name: "John",
            password: "secret123"
          }
        }
      }
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    params = result[:event].request_params
    assert_equal "John", params["user"]["name"]
    assert_equal "[FILTERED]", params["user"]["password"]
  end

  test "parses timestamp from string" do
    project = create_project
    timestamp_str = "2024-12-21T10:00:00Z"
    payload = sample_error_payload(timestamp: timestamp_str)

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    assert_equal Time.parse(timestamp_str).to_i, result[:event].occurred_at.to_i
  end

  test "parses timestamp from numeric" do
    project = create_project
    timestamp_num = Time.current.to_i
    payload = sample_error_payload(timestamp: timestamp_num)

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    assert_equal timestamp_num, result[:event].occurred_at.to_i
  end

  test "defaults to current time if timestamp invalid" do
    project = create_project
    payload = sample_error_payload(timestamp: "invalid")

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    assert_in_delta Time.current.to_i, result[:event].occurred_at.to_i, 1
  end

  test "extracts file path from backtrace" do
    project = create_project
    payload = sample_error_payload(
      backtrace: [ "app/models/user.rb:42:in `full_name'" ]
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    assert_equal "app/models/user.rb", result[:error_group].file_path
  end

  test "extracts line number from backtrace" do
    project = create_project
    payload = sample_error_payload(
      backtrace: [ "app/models/user.rb:42:in `full_name'" ]
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    assert_equal 42, result[:error_group].line_number
  end

  test "extracts function name from backtrace" do
    project = create_project
    payload = sample_error_payload(
      backtrace: [ "app/models/user.rb:42:in `full_name'" ]
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    assert_equal "full_name", result[:error_group].function_name
  end

  test "stores request context in event" do
    project = create_project
    payload = sample_error_payload(
      request: {
        id: "req_123",
        method: "POST",
        url: "https://example.com/users",
        path: "/users",
        params: { name: "John" },
        headers: { "User-Agent" => "Mozilla" }
      }
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    event = result[:event]
    assert_equal "req_123", event.request_id
    assert_equal "POST", event.request_method
    assert_equal "https://example.com/users", event.request_url
    assert_equal "/users", event.request_path
    assert_equal "John", event.request_params["name"]
    assert_equal "Mozilla", event.request_headers["User-Agent"]
  end

  test "stores user context in event" do
    project = create_project
    payload = sample_error_payload(
      user: {
        id: "user_123",
        email: "john@example.com",
        name: "John Doe"
      }
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    event = result[:event]
    assert_equal "user_123", event.user_id
    assert_equal "john@example.com", event.user_email
    assert_equal "John Doe", event.user_data["name"]
  end

  test "stores environment metadata in event" do
    project = create_project
    payload = sample_error_payload(
      environment: "staging",
      commit: "abc123",
      branch: "main",
      release: "v1.2.3",
      server_name: "web-1"
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    event = result[:event]
    assert_equal "staging", event.environment
    assert_equal "abc123", event.commit
    assert_equal "main", event.branch
    assert_equal "v1.2.3", event.release
    assert_equal "web-1", event.server_name
  end

  test "stores custom context, tags, and extra data" do
    project = create_project
    payload = sample_error_payload(
      context: { custom: "value" },
      tags: { team: "backend" },
      extra: { debug_info: "test" },
      breadcrumbs: [ { action: "user.login" } ]
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    event = result[:event]
    assert_equal "value", event.context["custom"]
    assert_equal "backend", event.tags["team"]
    assert_equal "test", event.extra["debug_info"]
    assert_equal "user.login", event.breadcrumbs[0]["action"]
  end

  test "handles empty request params" do
    project = create_project
    payload = sample_error_payload(
      request: { params: nil }
    )

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    assert_equal({}, result[:event].request_params)
  end

  test "deep symbolizes keys in payload" do
    project = create_project
    payload = {
      "error_class" => "NoMethodError",
      "message" => "Test",
      "backtrace" => [ "app/models/user.rb:42:in `method'" ],
      "request" => {
        "method" => "POST",
        "params" => { "name" => "John" }
      }
    }

    processor = ErrorProcessor.new(project: project, payload: payload)
    result = processor.process!

    assert result[:event].present?
    assert_equal "NoMethodError", result[:event].error_class
  end
end
