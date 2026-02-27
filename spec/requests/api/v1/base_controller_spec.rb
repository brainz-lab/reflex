# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::BaseController", type: :request do
  before do
    create(:project, platform_project_id: "prj_test123")
  end

  describe "authentication" do
    it "returns 401 when no API key is provided" do
      post api_v1_errors_url, params: sample_error_payload, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Invalid API key")
    end

    it "returns 401 when empty API key is provided" do
      post api_v1_errors_url,
        params: sample_error_payload,
        headers: { "Authorization" => "Bearer " },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when invalid API key format is provided" do
      post api_v1_errors_url,
        params: sample_error_payload,
        headers: { "Authorization" => "Bearer invalid_key" },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts Bearer token in Authorization header" do
      post api_v1_errors_url,
        params: sample_error_payload,
        headers: { "Authorization" => "Bearer valid_key" },
        as: :json

      expect(response).to have_http_status(:created)
    end

    it "accepts X-API-Key header" do
      post api_v1_errors_url,
        params: sample_error_payload,
        headers: { "X-API-Key" => "valid_key" },
        as: :json

      expect(response).to have_http_status(:created)
    end

    it "accepts api_key query parameter" do
      post "#{api_v1_errors_url}?api_key=valid_key",
        params: sample_error_payload,
        as: :json

      expect(response).to have_http_status(:created)
    end
  end

  describe "project API key authentication (rfx_ format)" do
    it "authenticates with project API key" do
      project = create(:project, platform_project_id: "prj_local")
      project.update!(settings: { "api_key" => "rfx_test_key_12345" })

      post api_v1_errors_url,
        params: sample_error_payload,
        headers: { "Authorization" => "Bearer rfx_test_key_12345" },
        as: :json

      expect(response).to have_http_status(:created)
    end

    it "returns 401 for invalid rfx_ key" do
      post api_v1_errors_url,
        params: sample_error_payload,
        headers: { "Authorization" => "Bearer rfx_nonexistent_key" },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "project creation/lookup" do
    it "creates project when authenticated with Platform key" do
      Project.destroy_all

      expect {
        post api_v1_errors_url,
          params: sample_error_payload,
          headers: { "Authorization" => "Bearer valid_key" },
          as: :json
      }.to change(Project, :count).by(1)

      expect(response).to have_http_status(:created)
      project = Project.last
      expect(project.platform_project_id).to eq("prj_test123")
      expect(project.name).to eq("Test Project")
    end

    it "reuses existing project when platform_project_id matches" do
      expect {
        post api_v1_errors_url,
          params: sample_error_payload,
          headers: { "Authorization" => "Bearer valid_key" },
          as: :json
      }.not_to change(Project, :count)

      expect(response).to have_http_status(:created)
    end
  end

  describe "feature access" do
    it "allows access in development environment" do
      post api_v1_errors_url,
        params: sample_error_payload,
        headers: { "Authorization" => "Bearer valid_key" },
        as: :json

      expect(response).to have_http_status(:created)
    end
  end
end
