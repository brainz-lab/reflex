# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorsChannel, type: :channel do
  let(:project) { create(:project) }

  describe "subscription" do
    it "subscribes successfully with valid project_id" do
      subscribe project_id: project.id
      expect(subscription).to be_confirmed
    end

    it "rejects subscription without project_id" do
      subscribe
      expect(subscription).to be_rejected
    end

    it "rejects subscription with invalid project_id" do
      subscribe project_id: SecureRandom.uuid
      expect(subscription).to be_rejected
    end

    it "unsubscribes successfully" do
      subscribe project_id: project.id
      unsubscribe
      expect(subscription).not_to have_streams
    end

    it "streams for project" do
      subscribe project_id: project.id
      expect(subscription).to have_stream_for(project)
    end
  end

  describe ".broadcast_new_error" do
    it "sends message" do
      error_group = create(:error_group, project: project)
      event = create(:error_event, error_group: error_group)

      expect {
        described_class.broadcast_new_error(project, error_group, event)
      }.to have_broadcasted_to(project).with(a_hash_including(type: "new_error"))
    end
  end

  describe ".broadcast_error_resolved" do
    it "sends message" do
      error_group = create(:error_group, project: project, status: "resolved")

      expect {
        described_class.broadcast_error_resolved(project, error_group)
      }.to have_broadcasted_to(project).with(a_hash_including(type: "error_resolved"))
    end

    it "includes status" do
      error_group = create(:error_group, project: project, status: "resolved")
      expect(error_group.status).to eq("resolved")
    end
  end

  describe ".broadcast_error_ignored" do
    it "sends message" do
      error_group = create(:error_group, project: project, status: "ignored")

      expect {
        described_class.broadcast_error_ignored(project, error_group)
      }.to have_broadcasted_to(project).with(a_hash_including(type: "error_ignored"))
    end
  end

  describe ".broadcast_error_unresolved" do
    it "sends message" do
      error_group = create(:error_group, project: project, status: "unresolved")

      expect {
        described_class.broadcast_error_unresolved(project, error_group)
      }.to have_broadcasted_to(project).with(a_hash_including(type: "error_unresolved"))
    end
  end

  describe ".error_group_payload" do
    it "includes required fields" do
      error_group = create(:error_group,
        project: project,
        error_class: "TestError",
        message: "Test message",
        event_count: 5,
        status: "unresolved"
      )

      payload = described_class.send(:error_group_payload, error_group)

      expect(payload[:id]).to eq(error_group.id)
      expect(payload[:error_class]).to eq("TestError")
      expect(payload[:message]).to be_present
      expect(payload[:event_count]).to eq(5)
      expect(payload[:status]).to eq("unresolved")
      expect(payload[:last_seen_at]).to be_present
    end
  end

  describe ".event_payload" do
    it "includes required fields" do
      error_group = create(:error_group, project: project)
      event = create(:error_event,
        error_group: error_group,
        environment: "production",
        commit: "abc123"
      )

      payload = described_class.send(:event_payload, event)

      expect(payload[:id]).to eq(event.id)
      expect(payload[:environment]).to eq("production")
      expect(payload[:commit]).to eq("abc123")
      expect(payload[:occurred_at]).to be_present
    end
  end
end
