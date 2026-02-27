# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::ProjectsController", type: :request do
  let(:master_key) { "test_master_key_12345" }

  before { ENV["REFLEX_MASTER_KEY"] = master_key }
  after { ENV.delete("REFLEX_MASTER_KEY") }

  describe "authentication" do
    it "requires master key authentication" do
      post api_v1_projects_provision_url, params: { name: "Test Project" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Unauthorized")
    end

    it "rejects invalid master key" do
      post api_v1_projects_provision_url,
        params: { name: "Test Project" },
        headers: { "X-Master-Key" => "wrong_key" },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts valid master key" do
      post api_v1_projects_provision_url,
        params: { name: "Test Project" },
        headers: { "X-Master-Key" => master_key },
        as: :json

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /api/v1/projects/provision" do
    it "creates new project" do
      expect {
        post api_v1_projects_provision_url,
          params: { name: "My New Project" },
          headers: { "X-Master-Key" => master_key },
          as: :json
      }.to change(Project, :count).by(1)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to be_present
      expect(json["name"]).to eq("My New Project")
      expect(json["api_key"]).to start_with("rfx_")
      expect(json["platform_project_id"]).to start_with("rfx_")
    end

    it "returns existing project by name" do
      project = create(:project, name: "Existing Project")
      project.update!(settings: { "api_key" => "rfx_existing_key" })

      expect {
        post api_v1_projects_provision_url,
          params: { name: "Existing Project" },
          headers: { "X-Master-Key" => master_key },
          as: :json
      }.not_to change(Project, :count)

      json = JSON.parse(response.body)
      expect(json["id"]).to eq(project.id)
      expect(json["api_key"]).to eq("rfx_existing_key")
    end

    it "requires name parameter" do
      post api_v1_projects_provision_url,
        params: {},
        headers: { "X-Master-Key" => master_key },
        as: :json

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)["error"]).to eq("Name is required")
    end

    it "rejects blank name" do
      post api_v1_projects_provision_url,
        params: { name: "   " },
        headers: { "X-Master-Key" => master_key },
        as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "accepts environment parameter" do
      post api_v1_projects_provision_url,
        params: { name: "Staging Project", environment: "staging" },
        headers: { "X-Master-Key" => master_key },
        as: :json

      expect(response).to have_http_status(:success)
      project = Project.find_by(name: "Staging Project")
      expect(project.environment).to eq("staging")
    end

    it "generates API key for new project" do
      post api_v1_projects_provision_url,
        params: { name: "New Project" },
        headers: { "X-Master-Key" => master_key },
        as: :json

      json = JSON.parse(response.body)
      expect(json["api_key"]).to be_present
      expect(json["api_key"]).to start_with("rfx_")
      expect(json["api_key"].length).to be > 10
    end
  end

  describe "GET /api/v1/projects/lookup" do
    it "finds existing project" do
      project = create(:project, name: "Lookup Test")
      project.update!(settings: { "api_key" => "rfx_lookup_key" })

      get api_v1_projects_lookup_url,
        params: { name: "Lookup Test" },
        headers: { "X-Master-Key" => master_key },
        as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["id"]).to eq(project.id)
      expect(json["name"]).to eq("Lookup Test")
      expect(json["api_key"]).to eq("rfx_lookup_key")
      expect(json["platform_project_id"]).to eq(project.platform_project_id)
    end

    it "returns 404 for nonexistent project" do
      get api_v1_projects_lookup_url,
        params: { name: "Nonexistent Project" },
        headers: { "X-Master-Key" => master_key },
        as: :json

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["error"]).to eq("Project not found")
    end

    it "requires master key" do
      create(:project, name: "Protected Project")

      get api_v1_projects_lookup_url,
        params: { name: "Protected Project" },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
