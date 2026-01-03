# frozen_string_literal: true

require "test_helper"

class Dashboard::BaseControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create project with the platform_project_id that matches our stubbed PlatformClient
    @project = create_project(platform_project_id: "prj_test123")
  end

  test "shows auth required page when no api_key provided" do
    get dashboard_project_errors_url(@project)
    assert_response :unauthorized
  end

  test "valid api_key grants access to matching project" do
    # valid_key is accepted by the stubbed PlatformClient and returns prj_test123
    get dashboard_project_errors_url(@project), params: { api_key: "valid_key" }
    assert_response :success
  end
end
