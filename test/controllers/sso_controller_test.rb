# frozen_string_literal: true

require "test_helper"

class SsoControllerTest < ActionDispatch::IntegrationTest
  setup do
    @platform_external_url = ENV["BRAINZLAB_PLATFORM_EXTERNAL_URL"] || "http://platform.localhost"
  end

  test "redirects to platform when token is blank" do
    get sso_callback_url

    assert_redirected_to @platform_external_url
  end

  test "redirects to platform when token is empty string" do
    get sso_callback_url(token: "")

    assert_redirected_to @platform_external_url
  end

  test "redirects to platform when token is whitespace only" do
    get sso_callback_url(token: "   ")

    assert_redirected_to @platform_external_url
  end

  # Note: Testing successful SSO validation would require webmock
  # to stub the platform API. For now, we test the edge cases
  # that don't require HTTP requests.
end
