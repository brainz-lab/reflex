# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendNotificationJob, type: :job do
  describe "#perform" do
    it "performs job successfully" do
      project = create(:project)
      error_group = create(:error_group, project: project)
      event = create(:error_event, error_group: error_group)

      expect { described_class.perform_now(error_group.id, event.id) }.not_to raise_error
    end

    it "handles missing error_group gracefully" do
      event = create(:error_event)

      expect {
        described_class.perform_now(SecureRandom.uuid, event.id)
      }.not_to raise_error
    end

    it "handles missing event gracefully" do
      error_group = create(:error_group)

      expect {
        described_class.perform_now(error_group.id, SecureRandom.uuid)
      }.not_to raise_error
    end

    it "handles missing both gracefully" do
      expect {
        described_class.perform_now(SecureRandom.uuid, SecureRandom.uuid)
      }.not_to raise_error
    end

    it "logs notification message" do
      project = create(:project)
      error_group = create(:error_group,
        project: project,
        error_class: "TestError",
        message: "Test message"
      )
      event = create(:error_event, error_group: error_group)

      log_output = StringIO.new
      old_logger = Rails.logger
      Rails.logger = Logger.new(log_output)

      described_class.perform_now(error_group.id, event.id)

      Rails.logger = old_logger

      log_content = log_output.string
      expect(log_content).to include("[Notification]")
      expect(log_content).to include("TestError")
    end

    it "can be enqueued" do
      project = create(:project)
      error_group = create(:error_group, project: project)
      event = create(:error_event, error_group: error_group)

      expect {
        described_class.perform_later(error_group.id, event.id)
      }.to have_enqueued_job(described_class)
    end
  end
end
