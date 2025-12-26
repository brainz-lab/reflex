require "test_helper"

class Api::V1::ErrorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = create_project(platform_project_id: "prj_test123")
    @api_key = "valid_key"
    @error_group = create_error_group(project: @project)
    @event = create_error_event(error_group: @error_group)
  end

  test "GET index returns error groups" do
    get api_v1_errors_url,
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["errors"].is_a?(Array)
    assert json["errors"].length > 0
  end

  test "GET index filters by status" do
    resolved = create_error_group(project: @project, status: "resolved")
    ignored = create_error_group(project: @project, status: "ignored")

    get api_v1_errors_url,
      params: { status: "resolved" },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    statuses = json["errors"].map { |e| e["status"] }

    assert_includes statuses, "resolved"
    assert_not_includes statuses, "ignored"
  end

  test "GET index filters by error_class" do
    create_error_group(project: @project, error_class: "NoMethodError")
    create_error_group(project: @project, error_class: "ArgumentError")

    get api_v1_errors_url,
      params: { error_class: "NoMethodError" },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    classes = json["errors"].map { |e| e["error_class"] }

    assert_includes classes, "NoMethodError"
    assert_not_includes classes, "ArgumentError"
  end

  test "GET index filters by since timestamp" do
    old = create_error_group(project: @project, last_seen_at: 2.days.ago)
    recent = create_error_group(project: @project, last_seen_at: 1.hour.ago)

    get api_v1_errors_url,
      params: { since: 1.day.ago.iso8601 },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    ids = json["errors"].map { |e| e["id"] }

    assert_includes ids, recent.id
    assert_not_includes ids, old.id
  end

  test "GET index sorts by recent (default)" do
    old = create_error_group(project: @project, last_seen_at: 2.hours.ago)
    new = create_error_group(project: @project, last_seen_at: 1.hour.ago)

    get api_v1_errors_url,
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    first_id = json["errors"].first["id"]

    assert_equal new.id, first_id
  end

  test "GET index sorts by frequent" do
    low = create_error_group(project: @project, event_count: 5)
    high = create_error_group(project: @project, event_count: 100)

    get api_v1_errors_url,
      params: { sort: "frequent" },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    first_id = json["errors"].first["id"]

    assert_equal high.id, first_id
  end

  test "GET index sorts by first_seen" do
    old = create_error_group(project: @project, first_seen_at: 2.days.ago)
    new = create_error_group(project: @project, first_seen_at: 1.day.ago)

    get api_v1_errors_url,
      params: { sort: "first_seen" },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    first_id = json["errors"].first["id"]

    assert_equal new.id, first_id
  end

  test "GET index limits results" do
    10.times { create_error_group(project: @project) }

    get api_v1_errors_url,
      params: { limit: 5 },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    assert_equal 5, json["errors"].length
  end

  test "GET index defaults to 50 limit" do
    get api_v1_errors_url,
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
  end

  test "GET show returns error details" do
    get api_v1_error_url(@error_group),
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal @error_group.id, json["error"]["id"]
    assert_equal @error_group.error_class, json["error"]["error_class"]
    assert json["recent_events"].is_a?(Array)
  end

  test "GET show includes recent events" do
    3.times { create_error_event(error_group: @error_group) }

    get api_v1_error_url(@error_group),
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    assert json["recent_events"].length > 0
  end

  test "GET show returns 404 for non-existent error" do
    get api_v1_error_url(id: SecureRandom.uuid),
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :not_found
  end

  test "POST resolve marks error as resolved" do
    post resolve_api_v1_error_url(@error_group),
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["resolved"]
    assert_equal "resolved", json["error"]["status"]

    @error_group.reload
    assert_equal "resolved", @error_group.status
  end

  test "POST ignore marks error as ignored" do
    post ignore_api_v1_error_url(@error_group),
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["ignored"]
    assert_equal "ignored", json["error"]["status"]

    @error_group.reload
    assert_equal "ignored", @error_group.status
  end

  test "POST unresolve marks error as unresolved" do
    @error_group.update!(status: "resolved")

    post unresolve_api_v1_error_url(@error_group),
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert json["unresolved"]
    assert_equal "unresolved", json["error"]["status"]

    @error_group.reload
    assert_equal "unresolved", @error_group.status
  end

  test "GET events returns error events" do
    3.times { create_error_event(error_group: @error_group) }

    get events_api_v1_error_url(@error_group),
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal @error_group.id, json["error_id"]
    assert json["events"].is_a?(Array)
    assert json["events"].length > 0
    assert json["total_count"] > 0
  end

  test "GET events filters by environment" do
    prod_event = create_error_event(error_group: @error_group, environment: "production")
    staging_event = create_error_event(error_group: @error_group, environment: "staging")

    get events_api_v1_error_url(@error_group),
      params: { environment: "production" },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    environments = json["events"].map { |e| e["environment"] }

    assert_includes environments, "production"
    assert_not_includes environments, "staging"
  end

  test "GET events limits results" do
    10.times { create_error_event(error_group: @error_group) }

    get events_api_v1_error_url(@error_group),
      params: { limit: 5 },
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    assert_equal 5, json["events"].length
  end

  test "requires authentication for all actions" do
    get api_v1_errors_url, as: :json
    assert_response :unauthorized

    get api_v1_error_url(@error_group), as: :json
    assert_response :unauthorized

    post resolve_api_v1_error_url(@error_group), as: :json
    assert_response :unauthorized
  end

  test "serializes error with all fields" do
    get api_v1_error_url(@error_group),
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    error = json["error"]

    assert error["id"].present?
    assert error["error_class"].present?
    assert error["message"].present?
    assert error["short_message"].present?
    assert error.key?("location")
    assert error.key?("file_path")
    assert error.key?("line_number")
    assert error.key?("function_name")
    assert error["status"].present?
    assert error.key?("event_count")
    assert error.key?("first_seen_at")
    assert error.key?("last_seen_at")
  end

  test "serializes event with all fields" do
    get api_v1_error_url(@error_group),
      headers: { "Authorization" => "Bearer #{@api_key}" },
      as: :json

    json = JSON.parse(response.body)
    event = json["recent_events"].first

    assert event["id"].present?
    assert event["error_class"].present?
    assert event.key?("message")
    assert event.key?("occurred_at")
    assert event.key?("environment")
    assert event.key?("backtrace")
    assert event.key?("user_id")
    assert event.key?("context")
    assert event.key?("tags")
  end
end
