# frozen_string_literal: true

require "test_helper"

class Api::V1::BaseControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = create_project(platform_project_id: "prj_test123")
  end

  # Authentication tests

  test "returns 401 when no API key is provided" do
    post api_v1_errors_url, params: sample_error_payload, as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Invalid API key", json["error"]
  end

  test "returns 401 when empty API key is provided" do
    post api_v1_errors_url,
      params: sample_error_payload,
      headers: { "Authorization" => "Bearer " },
      as: :json

    assert_response :unauthorized
  end

  test "returns 401 when invalid API key format is provided" do
    post api_v1_errors_url,
      params: sample_error_payload,
      headers: { "Authorization" => "Bearer invalid_key" },
      as: :json

    assert_response :unauthorized
  end

  test "accepts Bearer token in Authorization header" do
    post api_v1_errors_url,
      params: sample_error_payload,
      headers: { "Authorization" => "Bearer valid_key" },
      as: :json

    assert_response :created
  end

  test "accepts X-API-Key header" do
    post api_v1_errors_url,
      params: sample_error_payload,
      headers: { "X-API-Key" => "valid_key" },
      as: :json

    assert_response :created
  end

  test "accepts api_key query parameter" do
    post "#{api_v1_errors_url}?api_key=valid_key",
      params: sample_error_payload,
      as: :json

    assert_response :created
  end

  # Project API key authentication (rfx_ format)

  test "authenticates with project API key (rfx_ format)" do
    project = create_project(platform_project_id: "prj_local")
    project.update!(settings: { "api_key" => "rfx_test_key_12345" })

    post api_v1_errors_url,
      params: sample_error_payload,
      headers: { "Authorization" => "Bearer rfx_test_key_12345" },
      as: :json

    assert_response :created
  end

  test "returns 401 for invalid rfx_ key" do
    post api_v1_errors_url,
      params: sample_error_payload,
      headers: { "Authorization" => "Bearer rfx_nonexistent_key" },
      as: :json

    assert_response :unauthorized
  end

  # Project creation/lookup tests

  test "creates project when authenticated with Platform key" do
    # Remove existing project
    @project.destroy

    assert_difference "Project.count", 1 do
      post api_v1_errors_url,
        params: sample_error_payload,
        headers: { "Authorization" => "Bearer valid_key" },
        as: :json
    end

    assert_response :created
    project = Project.last
    assert_equal "prj_test123", project.platform_project_id
    assert_equal "Test Project", project.name
  end

  test "reuses existing project when platform_project_id matches" do
    assert_no_difference "Project.count" do
      post api_v1_errors_url,
        params: sample_error_payload,
        headers: { "Authorization" => "Bearer valid_key" },
        as: :json
    end

    assert_response :created
  end

  # Feature access tests

  test "allows access in development environment" do
    # The test environment allows access by default (see check_feature_access!)
    # This test verifies the authentication flow works
    post api_v1_errors_url,
      params: sample_error_payload,
      headers: { "Authorization" => "Bearer valid_key" },
      as: :json

    assert_response :created
  end
end
