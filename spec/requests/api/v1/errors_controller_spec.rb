# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::ErrorsController", type: :request do
  let!(:project) { create(:project, platform_project_id: "prj_test123") }
  let(:api_key) { "valid_key" }
  let(:auth_headers) { { "Authorization" => "Bearer #{api_key}" } }
  let!(:error_group) { create(:error_group, project: project) }
  let!(:event) { create(:error_event, error_group: error_group) }

  describe "GET /api/v1/errors" do
    it "returns error groups" do
      get api_v1_errors_url, headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["errors"]).to be_an(Array)
      expect(json["errors"].length).to be > 0
    end

    it "filters by status" do
      create(:error_group, project: project, status: "resolved")
      create(:error_group, project: project, status: "ignored")

      get api_v1_errors_url, params: { status: "resolved" }, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      statuses = json["errors"].map { |e| e["status"] }
      expect(statuses).to include("resolved")
      expect(statuses).not_to include("ignored")
    end

    it "filters by error_class" do
      create(:error_group, project: project, error_class: "NoMethodError")
      create(:error_group, project: project, error_class: "ArgumentError")

      get api_v1_errors_url, params: { error_class: "NoMethodError" }, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      classes = json["errors"].map { |e| e["error_class"] }
      expect(classes).to include("NoMethodError")
      expect(classes).not_to include("ArgumentError")
    end

    it "filters by since timestamp" do
      old = create(:error_group, project: project, last_seen_at: 2.days.ago)
      recent = create(:error_group, project: project, last_seen_at: 1.hour.ago)

      get api_v1_errors_url, params: { since: 1.day.ago.iso8601 }, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      ids = json["errors"].map { |e| e["id"] }
      expect(ids).to include(recent.id)
      expect(ids).not_to include(old.id)
    end

    it "sorts by recent (default)" do
      old = create(:error_group, project: project, last_seen_at: 2.hours.ago)
      recent = create(:error_group, project: project, last_seen_at: 1.hour.ago)

      get api_v1_errors_url, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json["errors"].first["id"]).to eq(recent.id)
    end

    it "sorts by frequent" do
      create(:error_group, project: project, event_count: 5)
      high = create(:error_group, project: project, event_count: 100)

      get api_v1_errors_url, params: { sort: "frequent" }, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json["errors"].first["id"]).to eq(high.id)
    end

    it "sorts by first_seen" do
      create(:error_group, project: project, first_seen_at: 2.days.ago)
      recent = create(:error_group, project: project, first_seen_at: 1.day.ago)

      get api_v1_errors_url, params: { sort: "first_seen" }, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json["errors"].first["id"]).to eq(recent.id)
    end

    it "limits results" do
      10.times { create(:error_group, project: project) }

      get api_v1_errors_url, params: { limit: 5 }, headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json["errors"].length).to eq(5)
    end

    it "defaults to 50 limit" do
      get api_v1_errors_url, headers: auth_headers, as: :json
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /api/v1/errors/:id" do
    it "returns error details" do
      get api_v1_error_url(error_group), headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["error"]["id"]).to eq(error_group.id)
      expect(json["error"]["error_class"]).to eq(error_group.error_class)
      expect(json["recent_events"]).to be_an(Array)
    end

    it "includes recent events" do
      3.times { create(:error_event, error_group: error_group) }

      get api_v1_error_url(error_group), headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      expect(json["recent_events"].length).to be > 0
    end

    it "returns 404 for non-existent error" do
      get api_v1_error_url(id: SecureRandom.uuid), headers: auth_headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/errors/:id/resolve" do
    it "marks error as resolved" do
      post resolve_api_v1_error_url(error_group), headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["resolved"]).to be true
      expect(json["error"]["status"]).to eq("resolved")

      error_group.reload
      expect(error_group.status).to eq("resolved")
    end
  end

  describe "POST /api/v1/errors/:id/ignore" do
    it "marks error as ignored" do
      post ignore_api_v1_error_url(error_group), headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["ignored"]).to be true
      expect(json["error"]["status"]).to eq("ignored")

      error_group.reload
      expect(error_group.status).to eq("ignored")
    end
  end

  describe "POST /api/v1/errors/:id/unresolve" do
    it "marks error as unresolved" do
      error_group.update!(status: "resolved")

      post unresolve_api_v1_error_url(error_group), headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["unresolved"]).to be true
      expect(json["error"]["status"]).to eq("unresolved")

      error_group.reload
      expect(error_group.status).to eq("unresolved")
    end
  end

  describe "GET /api/v1/errors/:id/events" do
    it "returns error events" do
      3.times { create(:error_event, error_group: error_group) }

      get events_api_v1_error_url(error_group), headers: auth_headers, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["error_id"]).to eq(error_group.id)
      expect(json["events"]).to be_an(Array)
      expect(json["events"].length).to be > 0
      expect(json["total_count"]).to be > 0
    end

    it "filters by environment" do
      create(:error_event, error_group: error_group, environment: "production")
      create(:error_event, error_group: error_group, environment: "staging")

      get events_api_v1_error_url(error_group),
        params: { environment: "production" },
        headers: auth_headers,
        as: :json

      json = JSON.parse(response.body)
      environments = json["events"].map { |e| e["environment"] }
      expect(environments).to include("production")
      expect(environments).not_to include("staging")
    end

    it "limits results" do
      10.times { create(:error_event, error_group: error_group) }

      get events_api_v1_error_url(error_group),
        params: { limit: 5 },
        headers: auth_headers,
        as: :json

      json = JSON.parse(response.body)
      expect(json["events"].length).to eq(5)
    end
  end

  describe "authentication required for all actions" do
    it "requires auth for index, show, and resolve" do
      get api_v1_errors_url, as: :json
      expect(response).to have_http_status(:unauthorized)

      get api_v1_error_url(error_group), as: :json
      expect(response).to have_http_status(:unauthorized)

      post resolve_api_v1_error_url(error_group), as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "serialization" do
    it "serializes error with all fields" do
      get api_v1_error_url(error_group), headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      error = json["error"]

      expect(error["id"]).to be_present
      expect(error["error_class"]).to be_present
      expect(error["message"]).to be_present
      expect(error["short_message"]).to be_present
      expect(error).to have_key("location")
      expect(error).to have_key("file_path")
      expect(error).to have_key("line_number")
      expect(error).to have_key("function_name")
      expect(error["status"]).to be_present
      expect(error).to have_key("event_count")
      expect(error).to have_key("first_seen_at")
      expect(error).to have_key("last_seen_at")
    end

    it "serializes event with all fields" do
      get api_v1_error_url(error_group), headers: auth_headers, as: :json

      json = JSON.parse(response.body)
      event_json = json["recent_events"].first

      expect(event_json["id"]).to be_present
      expect(event_json["error_class"]).to be_present
      expect(event_json).to have_key("message")
      expect(event_json).to have_key("occurred_at")
      expect(event_json).to have_key("environment")
      expect(event_json).to have_key("backtrace")
      expect(event_json).to have_key("user_id")
      expect(event_json).to have_key("context")
      expect(event_json).to have_key("tags")
    end
  end
end
