require "test_helper"

class Api::V1::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = create_project(platform_project_id: "prj_test123")
    @api_key = "valid_key"
  end

  test "POST create processes error and returns event" do
    payload = sample_error_payload

    assert_difference [ "ErrorGroup.count", "ErrorEvent.count" ], 1 do
      post api_v1_errors_url,
        params: payload,
        headers: { "Authorization" => "Bearer #{@api_key}" },
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)

    assert json["id"].present?
    assert json["error_group_id"].present?
    assert json["fingerprint"].present?
  end

  test "POST create finds existing error group" do
    payload = sample_error_payload

    # First request creates group and event
    post api_v1_errors_url,
      params: payload,
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    first_response = JSON.parse(response.body)

    # Second request with same payload should reuse group
    assert_no_difference "ErrorGroup.count" do
      assert_difference "ErrorEvent.count", 1 do
        post api_v1_errors_url,
          params: payload,
          headers: { "Authorization" => "Bearer #{@api_key}" },
          as: :json
      end
    end

    second_response = JSON.parse(response.body)
    assert_equal first_response["error_group_id"], second_response["error_group_id"]
  end

  test "POST create requires authentication" do
    payload = sample_error_payload

    post api_v1_errors_url, params: payload, as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Invalid API key", json["error"]
  end

  test "POST create accepts Authorization Bearer header" do
    payload = sample_error_payload

    post api_v1_errors_url,
      params: payload,
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :created
  end

  test "POST create accepts X-API-Key header" do
    payload = sample_error_payload

    post api_v1_errors_url,
      params: payload,
      headers: { "X-API-Key" => @api_key },
      as: :json

    assert_response :created
  end

  test "POST create accepts project API key format" do
    project = create_project(platform_project_id: "prj_local")
    project.update!(settings: { api_key: "rfx_localkey123" })

    payload = sample_error_payload

    post api_v1_errors_url,
      params: payload,
      headers: { "Authorization" => "Bearer rfx_localkey123" },
      as: :json

    assert_response :created
  end

  test "POST batch processes multiple errors" do
    errors = [
      sample_error_payload(error_class: "NoMethodError"),
      sample_error_payload(error_class: "ArgumentError"),
      sample_error_payload(error_class: "RuntimeError")
    ]

    assert_difference "ErrorEvent.count", 3 do
      post "/api/v1/errors/batch",
        params: { errors: errors },
        headers: { "Authorization" => "Bearer #{@api_key}" },
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)

    assert_equal 3, json["processed"]
    assert_equal 3, json["results"].length
  end

  test "POST batch accepts JSON array format" do
    errors = [
      sample_error_payload(error_class: "NoMethodError"),
      sample_error_payload(error_class: "ArgumentError")
    ]

    assert_difference "ErrorEvent.count", 2 do
      post "/api/v1/errors/batch",
        params: errors,
        headers: { "Authorization" => "Bearer #{@api_key}" },
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal 2, json["processed"]
  end

  test "POST batch returns all event IDs" do
    errors = [
      sample_error_payload(error_class: "Error1"),
      sample_error_payload(error_class: "Error2")
    ]

    post "/api/v1/errors/batch",
      params: { errors: errors },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)

    assert_equal 2, json["results"].length
    json["results"].each do |result|
      assert result["id"].present?
      assert result["error_group_id"].present?
    end
  end

  test "POST create_message creates message event" do
    assert_difference "ErrorEvent.count", 1 do
      post api_v1_messages_url,
        params: {
          message: "User logged in successfully",
          level: "info",
          environment: "production"
        },
        headers: { "Authorization" => "Bearer #{@api_key}" },
        as: :json
    end

    assert_response :created
    json = JSON.parse(response.body)

    assert json["id"].present?
    assert json["error_group_id"].present?

    # Verify the event was created with Message error_class
    event = ErrorEvent.find_by(id: json["id"])
    assert_equal "Message", event.error_class
    assert_equal "User logged in successfully", event.message
  end

  test "POST create handles exception format" do
    payload = {
      exception: {
        class: "CustomError",
        message: "Something went wrong",
        backtrace: [ "app/models/user.rb:42:in `method'" ]
      }
    }

    post api_v1_errors_url,
      params: payload,
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :created
    json = JSON.parse(response.body)
    assert json["id"].present?
  end

  test "POST create stores all error metadata" do
    payload = sample_error_payload(
      environment: "staging",
      commit: "abc123",
      branch: "feature-branch",
      release: "v1.2.3",
      server_name: "web-1",
      user: {
        id: "user_123",
        email: "test@example.com"
      },
      context: { custom: "value" },
      tags: { team: "backend" }
    )

    post api_v1_errors_url,
      params: payload,
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    event = ErrorEvent.find_by(id: json["id"])

    assert_equal "staging", event.environment
    assert_equal "abc123", event.commit
    assert_equal "feature-branch", event.branch
    assert_equal "v1.2.3", event.release
    assert_equal "web-1", event.server_name
    assert_equal "user_123", event.user_id
    assert_equal "test@example.com", event.user_email
    assert_equal "value", event.context["custom"]
    assert_equal "backend", event.tags["team"]
  end
end
