# frozen_string_literal: true

require "test_helper"

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @master_key = "test_master_key_12345"
    ENV["REFLEX_MASTER_KEY"] = @master_key
  end

  teardown do
    ENV.delete("REFLEX_MASTER_KEY")
  end

  # Authentication tests

  test "requires master key authentication" do
    post api_v1_projects_provision_url, params: { name: "Test Project" }, as: :json

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Unauthorized", json["error"]
  end

  test "rejects invalid master key" do
    post api_v1_projects_provision_url,
      params: { name: "Test Project" },
      headers: { "X-Master-Key" => "wrong_key" },
      as: :json

    assert_response :unauthorized
  end

  test "accepts valid master key" do
    post api_v1_projects_provision_url,
      params: { name: "Test Project" },
      headers: { "X-Master-Key" => @master_key },
      as: :json

    assert_response :success
  end

  # Provision endpoint tests

  test "provision creates new project" do
    assert_difference "Project.count", 1 do
      post api_v1_projects_provision_url,
        params: { name: "My New Project" },
        headers: { "X-Master-Key" => @master_key },
        as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)

    assert json["id"].present?
    assert_equal "My New Project", json["name"]
    assert json["api_key"].start_with?("rfx_")
    assert json["platform_project_id"].start_with?("rfx_")
  end

  test "provision returns existing project by name" do
    project = create_project(name: "Existing Project")
    project.update!(settings: { "api_key" => "rfx_existing_key" })

    assert_no_difference "Project.count" do
      post api_v1_projects_provision_url,
        params: { name: "Existing Project" },
        headers: { "X-Master-Key" => @master_key },
        as: :json
    end

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal project.id, json["id"]
    assert_equal "rfx_existing_key", json["api_key"]
  end

  test "provision requires name parameter" do
    post api_v1_projects_provision_url,
      params: {},
      headers: { "X-Master-Key" => @master_key },
      as: :json

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "Name is required", json["error"]
  end

  test "provision rejects blank name" do
    post api_v1_projects_provision_url,
      params: { name: "   " },
      headers: { "X-Master-Key" => @master_key },
      as: :json

    assert_response :bad_request
  end

  test "provision accepts environment parameter" do
    post api_v1_projects_provision_url,
      params: { name: "Staging Project", environment: "staging" },
      headers: { "X-Master-Key" => @master_key },
      as: :json

    assert_response :success
    project = Project.find_by(name: "Staging Project")
    assert_equal "staging", project.environment
  end

  test "provision generates API key for new project" do
    post api_v1_projects_provision_url,
      params: { name: "New Project" },
      headers: { "X-Master-Key" => @master_key },
      as: :json

    json = JSON.parse(response.body)
    assert json["api_key"].present?
    assert json["api_key"].start_with?("rfx_")
    assert json["api_key"].length > 10
  end

  # Lookup endpoint tests

  test "lookup finds existing project" do
    project = create_project(name: "Lookup Test")
    project.update!(settings: { "api_key" => "rfx_lookup_key" })

    get api_v1_projects_lookup_url,
      params: { name: "Lookup Test" },
      headers: { "X-Master-Key" => @master_key },
      as: :json

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal project.id, json["id"]
    assert_equal "Lookup Test", json["name"]
    assert_equal "rfx_lookup_key", json["api_key"]
    assert_equal project.platform_project_id, json["platform_project_id"]
  end

  test "lookup returns 404 for nonexistent project" do
    get api_v1_projects_lookup_url,
      params: { name: "Nonexistent Project" },
      headers: { "X-Master-Key" => @master_key },
      as: :json

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "Project not found", json["error"]
  end

  test "lookup requires master key" do
    project = create_project(name: "Protected Project")

    get api_v1_projects_lookup_url,
      params: { name: "Protected Project" },
      as: :json

    assert_response :unauthorized
  end
end
