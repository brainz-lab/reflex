# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorEvent, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:error_class) }
    it { is_expected.to validate_presence_of(:occurred_at) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:error_group).counter_cache(:event_count) }
    it { is_expected.to belong_to(:project).counter_cache(:event_count) }
  end

  describe "scope .recent" do
    it "orders by occurred_at desc" do
      error_group = create(:error_group)
      old_event = create(:error_event, error_group: error_group, occurred_at: 2.hours.ago)
      new_event = create(:error_event, error_group: error_group, occurred_at: 1.hour.ago)

      recent = error_group.events.recent
      expect(recent.first.id).to eq(new_event.id)
      expect(recent.last.id).to eq(old_event.id)
    end
  end

  describe "#parsed_backtrace" do
    it "handles string format" do
      event = create(:error_event, backtrace: [
        "app/models/user.rb:42:in `full_name'",
        "app/controllers/users_controller.rb:23:in `show'"
      ])

      parsed = event.parsed_backtrace

      expect(parsed.length).to eq(2)
      expect(parsed[0][:file]).to eq("app/models/user.rb")
      expect(parsed[0][:line]).to eq(42)
      expect(parsed[0][:function]).to eq("full_name'")
      expect(parsed[0][:in_app]).to be true

      expect(parsed[1][:file]).to eq("app/controllers/users_controller.rb")
      expect(parsed[1][:line]).to eq(23)
      expect(parsed[1][:function]).to eq("show'")
    end

    it "handles hash format" do
      event = create(:error_event, backtrace: [
        {
          "file" => "app/models/user.rb",
          "line" => 42,
          "function" => "full_name",
          "in_app" => true
        }
      ])

      parsed = event.parsed_backtrace

      expect(parsed.length).to eq(1)
      expect(parsed[0][:file]).to eq("app/models/user.rb")
      expect(parsed[0][:line]).to eq(42)
      expect(parsed[0][:function]).to eq("full_name")
      expect(parsed[0][:in_app]).to be true
    end

    it "handles raw frame format" do
      event = create(:error_event, backtrace: [
        { "raw" => "app/models/user.rb:42:in `full_name'" }
      ])

      parsed = event.parsed_backtrace

      expect(parsed.length).to eq(1)
      expect(parsed[0][:file]).to eq("app/models/user.rb")
      expect(parsed[0][:line]).to eq(42)
      expect(parsed[0][:function]).to eq("full_name'")
    end
  end

  describe "#in_app_path?" do
    let(:event) { create(:error_event) }

    it "returns true for app paths" do
      expect(event.in_app_path?("app/models/user.rb")).to be true
      expect(event.in_app_path?("lib/custom_module.rb")).to be true
      expect(event.in_app_path?("/full/path/app/models/user.rb")).to be true
      expect(event.in_app_path?("/full/path/lib/custom.rb")).to be true
    end

    it "returns false for gem paths" do
      expect(event.in_app_path?("/gems/rails-8.0/lib/action_controller.rb")).to be false
      expect(event.in_app_path?("vendor/bundle/rails.rb")).to be false
      expect(event.in_app_path?("/ruby/3.3.0/lib/timeout.rb")).to be false
    end

    it "returns false for nil" do
      expect(event.in_app_path?(nil)).to be false
    end
  end

  describe "#app_backtrace" do
    it "filters to in_app frames" do
      event = create(:error_event, backtrace: [
        "app/models/user.rb:42:in `full_name'",
        "/gems/activerecord/lib/active_record.rb:100:in `save'",
        "app/controllers/users_controller.rb:23:in `show'"
      ])

      app_frames = event.app_backtrace

      expect(app_frames.length).to eq(2)
      expect(app_frames[0][:file]).to eq("app/models/user.rb")
      expect(app_frames[1][:file]).to eq("app/controllers/users_controller.rb")
    end

    it "falls back to all frames if none marked in_app" do
      event = create(:error_event, backtrace: [
        "/gems/rails/lib/rails.rb:10:in `load'",
        "/ruby/3.3.0/lib/timeout.rb:5:in `timeout'"
      ])

      expect(event.app_backtrace.length).to eq(2)
    end
  end

  describe "#first_app_frame" do
    it "returns first in_app frame" do
      event = create(:error_event, backtrace: [
        "app/models/user.rb:42:in `full_name'",
        "app/controllers/users_controller.rb:23:in `show'"
      ])

      first_frame = event.first_app_frame

      expect(first_frame[:file]).to eq("app/models/user.rb")
      expect(first_frame[:line]).to eq(42)
    end
  end

  describe "counter caches" do
    it "increments error_group event_count" do
      error_group = create(:error_group, event_count: 5)
      create(:error_event, error_group: error_group)
      error_group.reload

      expect(error_group.event_count).to eq(6)
    end

    it "increments project event_count" do
      project = create(:project)
      error_group = create(:error_group, project: project)
      initial_count = project.event_count

      create(:error_event, error_group: error_group)
      project.reload

      expect(project.event_count).to eq(initial_count + 1)
    end
  end

  describe "JSONB fields" do
    it "stores correctly" do
      event = create(:error_event,
        context: { custom_field: "value" },
        tags: { environment: "production" },
        extra: { server: "web-1" },
        breadcrumbs: [{ action: "user.login", timestamp: Time.current.iso8601 }]
      )

      expect(event.context["custom_field"]).to eq("value")
      expect(event.tags["environment"]).to eq("production")
      expect(event.extra["server"]).to eq("web-1")
      expect(event.breadcrumbs.length).to eq(1)
    end
  end
end
