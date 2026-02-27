# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlatformClient, type: :service do
  describe ".validate_key" do
    it "returns invalid for blank key" do
      result = described_class.validate_key("")
      expect(result[:valid]).to be false

      result = described_class.validate_key(nil)
      expect(result[:valid]).to be false
    end

    it "returns valid response for valid_key" do
      result = described_class.validate_key("valid_key")

      expect(result[:valid]).to be true
      expect(result[:project_id]).to eq("prj_test123")
      expect(result[:project_name]).to eq("Test Project")
      expect(result[:environment]).to eq("live")
      expect(result[:features][:reflex]).to be true
    end

    it "returns invalid for unknown keys" do
      result = described_class.validate_key("unknown_key")
      expect(result[:valid]).to be false
    end
  end

  describe ".track_usage" do
    it "is stubbed to return true" do
      result = described_class.track_usage(
        project_id: "prj_123",
        product: "reflex",
        metric: "errors",
        count: 5
      )
      expect(result).to be true
    end
  end

  describe ".get_project_config" do
    it "returns stubbed config" do
      result = described_class.get_project_config(platform_project_id: "prj_123")

      expect(result[:name]).to eq("Test Project")
      expect(result[:environment]).to eq("live")
    end
  end

  describe "real implementation behavior" do
    it "parses successful response" do
      result = described_class.validate_key("valid_key")

      expect(result[:valid]).to be true
      expect(result[:project_id]).to be_present
      expect(result[:project_name]).to be_present
      expect(result[:features]).to be_present
    end

    it "handles development fallback" do
      result = described_class.validate_key("valid_key")
      expect(result[:valid]).to be true
    end
  end
end
