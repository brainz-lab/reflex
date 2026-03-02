# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::EventsController", type: :request do
  let!(:project) { create(:project, platform_project_id: "prj_test123") }
  let(:api_key) { "valid_key" }
  let(:auth_headers) { { "Authorization" => "Bearer #{api_key}" } }

  describe "POST /api/v1/errors" do
    it "processes error and returns event" do
      expect {
        post api_v1_errors_url,
          params: sample_error_payload,
          headers: auth_headers,
          as: :json
      }.to change(ErrorGroup, :count).by(1)
        .and change(ErrorEvent, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["id"]).to be_present
      expect(json["error_group_id"]).to be_present
      expect(json["fingerprint"]).to be_present
    end

    it "finds existing error group" do
      post api_v1_errors_url,
        params: sample_error_payload,
        headers: auth_headers,
        as: :json
      first_response = JSON.parse(response.body)

      expect {
        post api_v1_errors_url,
          params: sample_error_payload,
          headers: auth_headers,
          as: :json
      }.to change(ErrorEvent, :count).by(1)
        .and change(ErrorGroup, :count).by(0)

      second_response = JSON.parse(response.body)
      expect(second_response["error_group_id"]).to eq(first_response["error_group_id"])
    end

    it "requires authentication" do
      post api_v1_errors_url, params: sample_error_payload, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)["error"]).to eq("Invalid API key")
    end

    it "accepts Authorization Bearer header" do
      post api_v1_errors_url,
        params: sample_error_payload,
        headers: auth_headers,
        as: :json

      expect(response).to have_http_status(:created)
    end

    it "accepts X-API-Key header" do
      post api_v1_errors_url,
        params: sample_error_payload,
        headers: { "X-API-Key" => api_key },
        as: :json

      expect(response).to have_http_status(:created)
    end

    it "accepts project API key format" do
      local_project = create(:project, platform_project_id: "prj_local")
      local_project.update!(settings: { api_key: "rfx_localkey123" })

      post api_v1_errors_url,
        params: sample_error_payload,
        headers: { "Authorization" => "Bearer rfx_localkey123" },
        as: :json

      expect(response).to have_http_status(:created)
    end

    it "handles exception format" do
      payload = {
        exception: {
          class: "CustomError",
          message: "Something went wrong",
          backtrace: [ "app/models/user.rb:42:in `method'" ]
        }
      }

      post api_v1_errors_url,
        params: payload,
        headers: auth_headers,
        as: :json

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["id"]).to be_present
    end

    it "stores all error metadata" do
      payload = sample_error_payload(
        environment: "staging",
        commit: "abc123",
        branch: "feature-branch",
        release: "v1.2.3",
        server_name: "web-1",
        user: { id: "user_123", email: "test@example.com" },
        context: { custom: "value" },
        tags: { team: "backend" }
      )

      post api_v1_errors_url,
        params: payload,
        headers: auth_headers,
        as: :json

      json = JSON.parse(response.body)
      event = ErrorEvent.find_by(id: json["id"])

      expect(event.environment).to eq("staging")
      expect(event.commit).to eq("abc123")
      expect(event.branch).to eq("feature-branch")
      expect(event.release).to eq("v1.2.3")
      expect(event.server_name).to eq("web-1")
      expect(event.user_id).to eq("user_123")
      expect(event.user_email).to eq("test@example.com")
      expect(event.context["custom"]).to eq("value")
      expect(event.tags["team"]).to eq("backend")
    end
  end

  describe "POST /api/v1/errors/batch" do
    it "processes multiple errors" do
      errors = [
        sample_error_payload(error_class: "NoMethodError"),
        sample_error_payload(error_class: "ArgumentError"),
        sample_error_payload(error_class: "RuntimeError")
      ]

      expect {
        post "/api/v1/errors/batch",
          params: { errors: errors },
          headers: auth_headers,
          as: :json
      }.to change(ErrorEvent, :count).by(3)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["processed"]).to eq(3)
      expect(json["results"].length).to eq(3)
    end

    it "accepts JSON array format" do
      errors = [
        sample_error_payload(error_class: "NoMethodError"),
        sample_error_payload(error_class: "ArgumentError")
      ]

      expect {
        post "/api/v1/errors/batch",
          params: errors,
          headers: auth_headers,
          as: :json
      }.to change(ErrorEvent, :count).by(2)

      json = JSON.parse(response.body)
      expect(json["processed"]).to eq(2)
    end

    it "returns all event IDs" do
      errors = [
        sample_error_payload(error_class: "Error1"),
        sample_error_payload(error_class: "Error2")
      ]

      post "/api/v1/errors/batch",
        params: { errors: errors },
        headers: auth_headers,
        as: :json

      json = JSON.parse(response.body)
      expect(json["results"].length).to eq(2)
      json["results"].each do |result|
        expect(result["id"]).to be_present
        expect(result["error_group_id"]).to be_present
      end
    end
  end

  describe "POST /api/v1/messages" do
    it "creates message event" do
      expect {
        post api_v1_messages_url,
          params: {
            message: "User logged in successfully",
            level: "info",
            environment: "production"
          },
          headers: auth_headers,
          as: :json
      }.to change(ErrorEvent, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["id"]).to be_present

      event = ErrorEvent.find_by(id: json["id"])
      expect(event.error_class).to eq("Message")
      expect(event.message).to eq("User logged in successfully")
    end
  end
end
