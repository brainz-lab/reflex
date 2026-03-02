# frozen_string_literal: true

require "rails_helper"

RSpec.describe FingerprintGenerator, type: :service do
  describe ".generate" do
    it "generates consistent fingerprint for same error" do
      payload1 = {
        error_class: "NoMethodError",
        message: "undefined method 'foo' for nil:NilClass",
        backtrace: [ "app/models/user.rb:42:in `full_name'" ]
      }
      payload2 = payload1.dup

      expect(described_class.generate(payload1)).to eq(described_class.generate(payload2))
    end

    it "generates different fingerprint for different error class" do
      payload1 = sample_error_payload(error_class: "NoMethodError")
      payload2 = sample_error_payload(error_class: "ArgumentError")

      expect(described_class.generate(payload1)).not_to eq(described_class.generate(payload2))
    end

    it "generates different fingerprint for different file" do
      payload1 = sample_error_payload(backtrace: [ "app/models/user.rb:42:in `full_name'" ])
      payload2 = sample_error_payload(backtrace: [ "app/models/post.rb:42:in `full_name'" ])

      expect(described_class.generate(payload1)).not_to eq(described_class.generate(payload2))
    end

    it "generates different fingerprint for different function" do
      payload1 = sample_error_payload(backtrace: [ "app/models/user.rb:42:in `full_name'" ])
      payload2 = sample_error_payload(backtrace: [ "app/models/user.rb:42:in `email'" ])

      expect(described_class.generate(payload1)).not_to eq(described_class.generate(payload2))
    end

    it "normalizes numeric values in message" do
      payload1 = sample_error_payload(message: "Expected 5 arguments")
      payload2 = sample_error_payload(message: "Expected 10 arguments")

      expect(described_class.generate(payload1)).to eq(described_class.generate(payload2))
    end

    it "normalizes quoted strings in message" do
      payload1 = sample_error_payload(message: 'undefined method "foo"')
      payload2 = sample_error_payload(message: 'undefined method "bar"')

      expect(described_class.generate(payload1)).to eq(described_class.generate(payload2))
    end

    it "generates 16 character fingerprint" do
      payload = sample_error_payload
      expect(described_class.generate(payload).length).to eq(16)
    end

    it "generates hexadecimal fingerprint" do
      payload = sample_error_payload
      expect(described_class.generate(payload)).to match(/^[0-9a-f]{16}$/)
    end

    it "handles empty backtrace gracefully" do
      payload = sample_error_payload(backtrace: [])
      expect { described_class.generate(payload) }.not_to raise_error
    end

    it "handles missing message gracefully" do
      payload = {
        error_class: "NoMethodError",
        backtrace: [ "app/models/user.rb:42:in `full_name'" ]
      }
      expect { described_class.generate(payload) }.not_to raise_error
    end
  end

  describe ".normalize_message" do
    it "replaces numbers with N" do
      normalized = described_class.normalize_message("Expected 42 arguments, got 10")

      expect(normalized).to include("N")
      expect(normalized).not_to include("42")
      expect(normalized).not_to include("10")
    end

    it "replaces hex IDs with ID" do
      normalized = described_class.normalize_message("Cannot find abc123def")

      expect(normalized).to include("ID")
      expect(normalized).not_to include("abc123def")
    end

    it "replaces double quoted strings" do
      normalized = described_class.normalize_message('undefined method "foo" for object')

      expect(normalized).to include('"..."')
      expect(normalized).not_to include('"foo"')
    end

    it "replaces single quoted strings" do
      normalized = described_class.normalize_message("undefined method 'foo' for object")

      expect(normalized).to include("'...'")
      expect(normalized).not_to include("'foo'")
    end

    it "truncates long messages" do
      normalized = described_class.normalize_message("a" * 300)
      expect(normalized.length).to be <= 203
    end

    it "returns nil for nil input" do
      expect(described_class.normalize_message(nil)).to be_nil
    end
  end

  describe ".extract_file" do
    it "handles string backtrace format" do
      payload = sample_error_payload(backtrace: [ "app/models/user.rb:42:in `full_name'" ])
      expect(described_class.extract_file(payload)).to eq("app/models/user.rb")
    end

    it "handles hash backtrace format" do
      payload = sample_error_payload(
        backtrace: [ { "file" => "app/models/user.rb", "line" => 42 } ]
      )
      expect(described_class.extract_file(payload)).to eq("app/models/user.rb")
    end

    it "handles exception.backtrace format" do
      payload = {
        exception: {
          class: "NoMethodError",
          backtrace: [ "app/models/user.rb:42:in `full_name'" ]
        }
      }
      expect(described_class.extract_file(payload)).to eq("app/models/user.rb")
    end
  end

  describe ".extract_function" do
    it "handles string backtrace format" do
      payload = sample_error_payload(backtrace: [ "app/models/user.rb:42:in `full_name'" ])
      expect(described_class.extract_function(payload)).to eq("full_name")
    end

    it "handles hash backtrace format" do
      payload = sample_error_payload(
        backtrace: [ { "file" => "app/models/user.rb", "function" => "full_name" } ]
      )
      expect(described_class.extract_function(payload)).to eq("full_name")
    end
  end

  describe ".normalize_hex_ids" do
    it "normalizes hex IDs in message" do
      payload = sample_error_payload(message: "Cannot find record abc123defabc")
      normalized = described_class.normalize_message(payload[:message])

      expect(normalized).to include("ID")
      expect(normalized).not_to include("abc123defabc")
    end
  end
end
