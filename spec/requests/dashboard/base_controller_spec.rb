# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard::BaseController", type: :request do
  let!(:project) { create(:project, platform_project_id: "prj_test123") }

  it "shows auth required page when no api_key provided" do
    get dashboard_project_errors_url(project)
    expect(response).to have_http_status(:unauthorized)
  end

  it "valid api_key grants access to matching project" do
    get dashboard_project_errors_url(project), params: { api_key: "valid_key" }
    expect(response).to have_http_status(:success)
  end
end
