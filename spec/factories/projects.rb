# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    sequence(:platform_project_id) { |n| "prj_#{SecureRandom.hex(8)}" }
    name { "Test Project" }
    environment { "live" }
  end
end
