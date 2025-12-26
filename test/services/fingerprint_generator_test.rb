require "test_helper"

class FingerprintGeneratorTest < ActiveSupport::TestCase
  test "generates consistent fingerprint for same error" do
    payload1 = {
      error_class: "NoMethodError",
      message: "undefined method 'foo' for nil:NilClass",
      backtrace: ["app/models/user.rb:42:in `full_name'"]
    }

    payload2 = {
      error_class: "NoMethodError",
      message: "undefined method 'foo' for nil:NilClass",
      backtrace: ["app/models/user.rb:42:in `full_name'"]
    }

    fingerprint1 = FingerprintGenerator.generate(payload1)
    fingerprint2 = FingerprintGenerator.generate(payload2)

    assert_equal fingerprint1, fingerprint2
  end

  test "generates different fingerprint for different error class" do
    payload1 = sample_error_payload(error_class: "NoMethodError")
    payload2 = sample_error_payload(error_class: "ArgumentError")

    fingerprint1 = FingerprintGenerator.generate(payload1)
    fingerprint2 = FingerprintGenerator.generate(payload2)

    assert_not_equal fingerprint1, fingerprint2
  end

  test "generates different fingerprint for different file" do
    payload1 = sample_error_payload(
      backtrace: ["app/models/user.rb:42:in `full_name'"]
    )
    payload2 = sample_error_payload(
      backtrace: ["app/models/post.rb:42:in `full_name'"]
    )

    fingerprint1 = FingerprintGenerator.generate(payload1)
    fingerprint2 = FingerprintGenerator.generate(payload2)

    assert_not_equal fingerprint1, fingerprint2
  end

  test "generates different fingerprint for different function" do
    payload1 = sample_error_payload(
      backtrace: ["app/models/user.rb:42:in `full_name'"]
    )
    payload2 = sample_error_payload(
      backtrace: ["app/models/user.rb:42:in `email'"]
    )

    fingerprint1 = FingerprintGenerator.generate(payload1)
    fingerprint2 = FingerprintGenerator.generate(payload2)

    assert_not_equal fingerprint1, fingerprint2
  end

  test "normalizes numeric values in message" do
    payload1 = sample_error_payload(message: "Expected 5 arguments")
    payload2 = sample_error_payload(message: "Expected 10 arguments")

    fingerprint1 = FingerprintGenerator.generate(payload1)
    fingerprint2 = FingerprintGenerator.generate(payload2)

    assert_equal fingerprint1, fingerprint2
  end

  test "normalizes hex IDs in message" do
    # Test that different hex IDs get normalized to the same value
    payload = sample_error_payload(message: "Cannot find record abc123defabc")
    normalized = FingerprintGenerator.normalize_message(payload[:message])

    # The hex ID should be replaced with "ID"
    assert_includes normalized, "ID"
    assert_not_includes normalized, "abc123defabc"
  end

  test "normalizes quoted strings in message" do
    payload1 = sample_error_payload(message: 'undefined method "foo"')
    payload2 = sample_error_payload(message: 'undefined method "bar"')

    fingerprint1 = FingerprintGenerator.generate(payload1)
    fingerprint2 = FingerprintGenerator.generate(payload2)

    assert_equal fingerprint1, fingerprint2
  end

  test "extract_file handles string backtrace format" do
    payload = sample_error_payload(
      backtrace: ["app/models/user.rb:42:in `full_name'"]
    )

    file = FingerprintGenerator.extract_file(payload)
    assert_equal "app/models/user.rb", file
  end

  test "extract_file handles hash backtrace format" do
    payload = sample_error_payload(
      backtrace: [
        { "file" => "app/models/user.rb", "line" => 42 }
      ]
    )

    file = FingerprintGenerator.extract_file(payload)
    assert_equal "app/models/user.rb", file
  end

  test "extract_file handles exception.backtrace format" do
    payload = {
      exception: {
        class: "NoMethodError",
        backtrace: ["app/models/user.rb:42:in `full_name'"]
      }
    }

    file = FingerprintGenerator.extract_file(payload)
    assert_equal "app/models/user.rb", file
  end

  test "extract_function handles string backtrace format" do
    payload = sample_error_payload(
      backtrace: ["app/models/user.rb:42:in `full_name'"]
    )

    function = FingerprintGenerator.extract_function(payload)
    assert_equal "full_name", function
  end

  test "extract_function handles hash backtrace format" do
    payload = sample_error_payload(
      backtrace: [
        { "file" => "app/models/user.rb", "function" => "full_name" }
      ]
    )

    function = FingerprintGenerator.extract_function(payload)
    assert_equal "full_name", function
  end

  test "normalize_message replaces numbers with N" do
    message = "Expected 42 arguments, got 10"
    normalized = FingerprintGenerator.normalize_message(message)

    assert_includes normalized, "N"
    assert_not_includes normalized, "42"
    assert_not_includes normalized, "10"
  end

  test "normalize_message replaces hex IDs with ID" do
    message = "Cannot find abc123def"
    normalized = FingerprintGenerator.normalize_message(message)

    assert_includes normalized, "ID"
    assert_not_includes normalized, "abc123def"
  end

  test "normalize_message replaces double quoted strings" do
    message = 'undefined method "foo" for object'
    normalized = FingerprintGenerator.normalize_message(message)

    assert_includes normalized, '"..."'
    assert_not_includes normalized, '"foo"'
  end

  test "normalize_message replaces single quoted strings" do
    message = "undefined method 'foo' for object"
    normalized = FingerprintGenerator.normalize_message(message)

    assert_includes normalized, "'...'"
    assert_not_includes normalized, "'foo'"
  end

  test "normalize_message truncates long messages" do
    message = "a" * 300
    normalized = FingerprintGenerator.normalize_message(message)

    # truncate limits to 200 characters (may add "..." making it up to 203)
    assert normalized.length <= 203
  end

  test "normalize_message returns nil for nil input" do
    normalized = FingerprintGenerator.normalize_message(nil)
    assert_nil normalized
  end

  test "generates 16 character fingerprint" do
    payload = sample_error_payload
    fingerprint = FingerprintGenerator.generate(payload)

    assert_equal 16, fingerprint.length
  end

  test "generates hexadecimal fingerprint" do
    payload = sample_error_payload
    fingerprint = FingerprintGenerator.generate(payload)

    assert_match /^[0-9a-f]{16}$/, fingerprint
  end

  test "handles empty backtrace gracefully" do
    payload = sample_error_payload(backtrace: [])

    assert_nothing_raised do
      FingerprintGenerator.generate(payload)
    end
  end

  test "handles missing message gracefully" do
    payload = {
      error_class: "NoMethodError",
      backtrace: ["app/models/user.rb:42:in `full_name'"]
    }

    assert_nothing_raised do
      FingerprintGenerator.generate(payload)
    end
  end
end
