# frozen_string_literal: true

FactoryBot.define do
  factory :error_group do
    project
    sequence(:fingerprint) { |n| SecureRandom.hex(8) }
    error_class { "NoMethodError" }
    message { "undefined method 'foo' for nil:NilClass" }
    file_path { "app/models/user.rb" }
    line_number { 42 }
    function_name { "full_name" }
    status { "unresolved" }
    first_seen_at { Time.current }
    last_seen_at { Time.current }
  end
end
