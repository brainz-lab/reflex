# frozen_string_literal: true

FactoryBot.define do
  factory :error_event do
    error_group
    project { error_group.project }
    error_class { error_group.error_class }
    message { error_group.message }
    backtrace do
      [
        {
          "file" => "app/models/user.rb",
          "line" => 42,
          "function" => "full_name",
          "in_app" => true
        }
      ]
    end
    environment { "production" }
    occurred_at { Time.current }
  end
end
