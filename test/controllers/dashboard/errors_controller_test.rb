# frozen_string_literal: true

require "test_helper"

class Dashboard::ErrorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = create_project(platform_project_id: "prj_test123")
    @error_group = create_error_group(project: @project)
  end

  # Index tests

  test "index requires authentication" do
    get dashboard_project_errors_url(@project)
    assert_response :unauthorized
  end

  test "index renders with valid authentication" do
    get dashboard_project_errors_url(@project), params: { api_key: "valid_key" }
    assert_response :success
  end

  test "index filters by status parameter" do
    create_error_group(project: @project, status: "unresolved")
    create_error_group(project: @project, status: "resolved")

    get dashboard_project_errors_url(@project), params: { api_key: "valid_key", status: "resolved" }
    assert_response :success
  end

  test "index filters by error_class parameter" do
    create_error_group(project: @project, error_class: "NoMethodError")
    create_error_group(project: @project, error_class: "ArgumentError")

    get dashboard_project_errors_url(@project), params: { api_key: "valid_key", error_class: "NoMethodError" }
    assert_response :success
  end

  test "index accepts search query" do
    create_error_group(project: @project, error_class: "NoMethodError")

    get dashboard_project_errors_url(@project), params: { api_key: "valid_key", q: "NoMethod" }
    assert_response :success
  end

  # Show tests

  test "show requires authentication" do
    get dashboard_project_error_url(@project, @error_group)
    assert_response :unauthorized
  end

  test "show renders with valid authentication" do
    get dashboard_project_error_url(@project, @error_group), params: { api_key: "valid_key" }
    assert_response :success
  end

  # Action tests

  test "resolve requires authentication" do
    post resolve_dashboard_project_error_url(@project, @error_group)
    assert_response :unauthorized
  end

  test "resolve updates status and redirects" do
    post resolve_dashboard_project_error_url(@project, @error_group), params: { api_key: "valid_key" }
    assert_response :redirect

    @error_group.reload
    assert_equal "resolved", @error_group.status
  end

  test "ignore requires authentication" do
    post ignore_dashboard_project_error_url(@project, @error_group)
    assert_response :unauthorized
  end

  test "ignore updates status and redirects" do
    post ignore_dashboard_project_error_url(@project, @error_group), params: { api_key: "valid_key" }
    assert_response :redirect

    @error_group.reload
    assert_equal "ignored", @error_group.status
  end

  test "unresolve requires authentication" do
    @error_group.resolve!
    post unresolve_dashboard_project_error_url(@project, @error_group)
    assert_response :unauthorized
  end

  test "unresolve updates status and redirects" do
    @error_group.resolve!
    post unresolve_dashboard_project_error_url(@project, @error_group), params: { api_key: "valid_key" }
    assert_response :redirect

    @error_group.reload
    assert_equal "unresolved", @error_group.status
  end
end
