# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard::ErrorsController", type: :request do
  let!(:project) { create(:project, platform_project_id: "prj_test123") }
  let!(:error_group) { create(:error_group, project: project) }

  describe "GET index" do
    it "requires authentication" do
      get dashboard_project_errors_url(project)
      expect(response).to have_http_status(:unauthorized)
    end

    it "renders with valid authentication" do
      get dashboard_project_errors_url(project), params: { api_key: "valid_key" }
      expect(response).to have_http_status(:success)
    end

    it "filters by status parameter" do
      create(:error_group, project: project, status: "unresolved")
      create(:error_group, project: project, status: "resolved")

      get dashboard_project_errors_url(project), params: { api_key: "valid_key", status: "resolved" }
      expect(response).to have_http_status(:success)
    end

    it "filters by error_class parameter" do
      create(:error_group, project: project, error_class: "NoMethodError")
      create(:error_group, project: project, error_class: "ArgumentError")

      get dashboard_project_errors_url(project), params: { api_key: "valid_key", error_class: "NoMethodError" }
      expect(response).to have_http_status(:success)
    end

    it "accepts search query" do
      create(:error_group, project: project, error_class: "NoMethodError")

      get dashboard_project_errors_url(project), params: { api_key: "valid_key", q: "NoMethod" }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET show" do
    it "requires authentication" do
      get dashboard_project_error_url(project, error_group)
      expect(response).to have_http_status(:unauthorized)
    end

    it "renders with valid authentication" do
      get dashboard_project_error_url(project, error_group), params: { api_key: "valid_key" }
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST resolve" do
    it "requires authentication" do
      post resolve_dashboard_project_error_url(project, error_group)
      expect(response).to have_http_status(:unauthorized)
    end

    it "updates status and redirects" do
      post resolve_dashboard_project_error_url(project, error_group), params: { api_key: "valid_key" }
      expect(response).to have_http_status(:redirect)

      error_group.reload
      expect(error_group.status).to eq("resolved")
    end
  end

  describe "POST ignore" do
    it "requires authentication" do
      post ignore_dashboard_project_error_url(project, error_group)
      expect(response).to have_http_status(:unauthorized)
    end

    it "updates status and redirects" do
      post ignore_dashboard_project_error_url(project, error_group), params: { api_key: "valid_key" }
      expect(response).to have_http_status(:redirect)

      error_group.reload
      expect(error_group.status).to eq("ignored")
    end
  end

  describe "POST unresolve" do
    before { error_group.resolve! }

    it "requires authentication" do
      post unresolve_dashboard_project_error_url(project, error_group)
      expect(response).to have_http_status(:unauthorized)
    end

    it "updates status and redirects" do
      post unresolve_dashboard_project_error_url(project, error_group), params: { api_key: "valid_key" }
      expect(response).to have_http_status(:redirect)

      error_group.reload
      expect(error_group.status).to eq("unresolved")
    end
  end
end
