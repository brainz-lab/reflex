# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SsoController", type: :request do
  let(:platform_external_url) { ENV["BRAINZLAB_PLATFORM_EXTERNAL_URL"] || "http://platform.localhost" }

  it "redirects to platform when token is blank" do
    get sso_callback_url
    expect(response).to redirect_to(platform_external_url)
  end

  it "redirects to platform when token is empty string" do
    get sso_callback_url(token: "")
    expect(response).to redirect_to(platform_external_url)
  end

  it "redirects to platform when token is whitespace only" do
    get sso_callback_url(token: "   ")
    expect(response).to redirect_to(platform_external_url)
  end
end
