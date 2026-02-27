# frozen_string_literal: true

require "rails_helper"

RSpec.describe ErrorGroup, type: :model do
  describe "validations" do
    subject { build(:error_group) }

    it { is_expected.to validate_presence_of(:fingerprint) }
    it { is_expected.to validate_uniqueness_of(:fingerprint).scoped_to(:project_id) }
    it { is_expected.to validate_presence_of(:error_class) }
    it { is_expected.to validate_inclusion_of(:status).in_array(ErrorGroup::STATUSES) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:project).counter_cache(:error_count) }
    it { is_expected.to have_many(:events).class_name("ErrorEvent").dependent(:destroy) }
  end

  describe "same fingerprint allowed in different projects" do
    it "allows duplicate fingerprints across projects" do
      project1 = create(:project)
      project2 = create(:project)
      create(:error_group, project: project1, fingerprint: "shared123")

      error_group2 = build(:error_group, project: project2, fingerprint: "shared123")
      expect(error_group2).to be_valid
    end
  end

  describe "accepts valid statuses" do
    it "accepts all defined statuses" do
      project = create(:project)
      ErrorGroup::STATUSES.each do |status|
        error_group = create(:error_group, project: project, status: status)
        expect(error_group).to be_valid
      end
    end
  end

  describe "scopes" do
    let(:project) { create(:project) }

    describe ".unresolved" do
      it "returns only unresolved groups" do
        unresolved = create(:error_group, project: project, status: "unresolved")
        create(:error_group, project: project, status: "resolved")

        expect(described_class.unresolved).to include(unresolved)
        expect(described_class.unresolved).not_to include(ErrorGroup.resolved.first)
      end
    end

    describe ".resolved" do
      it "returns only resolved groups" do
        resolved = create(:error_group, project: project, status: "resolved")
        unresolved = create(:error_group, project: project, status: "unresolved")

        expect(described_class.resolved).to include(resolved)
        expect(described_class.resolved).not_to include(unresolved)
      end
    end

    describe ".ignored" do
      it "returns only ignored groups" do
        ignored = create(:error_group, project: project, status: "ignored")
        unresolved = create(:error_group, project: project, status: "unresolved")

        expect(described_class.ignored).to include(ignored)
        expect(described_class.ignored).not_to include(unresolved)
      end
    end

    describe ".muted" do
      it "returns only muted groups" do
        muted = create(:error_group, project: project, status: "muted")
        unresolved = create(:error_group, project: project, status: "unresolved")

        expect(described_class.muted).to include(muted)
        expect(described_class.muted).not_to include(unresolved)
      end
    end

    describe ".active" do
      it "returns unresolved and muted groups" do
        unresolved = create(:error_group, project: project, status: "unresolved")
        muted = create(:error_group, project: project, status: "muted")
        resolved = create(:error_group, project: project, status: "resolved")

        active_groups = described_class.active
        expect(active_groups).to include(unresolved, muted)
        expect(active_groups).not_to include(resolved)
      end
    end

    describe ".recent" do
      it "orders by last_seen_at desc" do
        old = create(:error_group, project: project, last_seen_at: 2.hours.ago)
        recent = create(:error_group, project: project, last_seen_at: 1.hour.ago)

        result = project.error_groups.recent
        expect(result.first).to eq(recent)
        expect(result.last).to eq(old)
      end
    end

    describe ".frequent" do
      it "orders by event_count desc" do
        low = create(:error_group, project: project, event_count: 5)
        high = create(:error_group, project: project, event_count: 100)

        result = project.error_groups.frequent
        expect(result.first).to eq(high)
        expect(result.last).to eq(low)
      end
    end
  end

  describe "#resolve!" do
    it "marks as resolved" do
      error_group = create(:error_group, status: "unresolved")
      error_group.resolve!(user_id: "user_123")

      expect(error_group.status).to eq("resolved")
      expect(error_group.resolved_at).not_to be_nil
      expect(error_group.resolved_by).to eq("user_123")
    end
  end

  describe "#unresolve!" do
    it "marks as unresolved" do
      error_group = create(:error_group,
        status: "resolved",
        resolved_at: 1.hour.ago,
        resolved_by: "user_123"
      )

      error_group.unresolve!

      expect(error_group.status).to eq("unresolved")
      expect(error_group.resolved_at).to be_nil
      expect(error_group.resolved_by).to be_nil
    end
  end

  describe "#ignore!" do
    it "marks as ignored" do
      error_group = create(:error_group, status: "unresolved")
      error_group.ignore!

      expect(error_group.status).to eq("ignored")
    end
  end

  describe "#mute!" do
    it "marks as muted" do
      error_group = create(:error_group, status: "unresolved")
      error_group.mute!

      expect(error_group.status).to eq("muted")
    end
  end

  describe "#record_occurrence!" do
    it "updates stats" do
      error_group = create(:error_group, event_count: 5, last_seen_at: 1.hour.ago)
      event = create(:error_event,
        error_group: error_group,
        occurred_at: Time.current,
        commit: "xyz789",
        environment: "staging"
      )

      error_group.reload
      initial_count = error_group.event_count
      error_group.record_occurrence!(event)

      expect(error_group.event_count).to eq(initial_count + 1)
      expect(error_group.last_seen_at.to_i).to be_within(1).of(Time.current.to_i)
      expect(error_group.last_commit).to eq("xyz789")
      expect(error_group.last_environment).to eq("staging")
    end

    it "unresolves if resolved" do
      error_group = create(:error_group, status: "resolved", resolved_at: 1.hour.ago)
      event = create(:error_event, error_group: error_group)

      error_group.record_occurrence!(event)

      expect(error_group.status).to eq("unresolved")
      expect(error_group.resolved_at).to be_nil
    end
  end

  describe "#resolved?" do
    it "returns true when resolved" do
      error_group = create(:error_group, status: "resolved")
      expect(error_group).to be_resolved
    end

    it "returns false when not resolved" do
      error_group = create(:error_group, status: "unresolved")
      expect(error_group).not_to be_resolved
    end
  end

  describe "#short_message" do
    it "truncates to 100 chars" do
      error_group = create(:error_group, message: "a" * 150)
      expect(error_group.short_message.length).to eq(100)
    end

    it "returns first line for multiline messages" do
      error_group = create(:error_group, message: "First line\nSecond line\nThird line")
      expect(error_group.short_message).to start_with("First line")
    end
  end

  describe "#location" do
    it "returns formatted location string" do
      error_group = create(:error_group,
        file_path: "app/models/user.rb",
        line_number: 42,
        function_name: "full_name"
      )

      expect(error_group.location).to eq("app/models/user.rb:42 in full_name")
    end

    it "returns nil when file_path is nil" do
      error_group = create(:error_group, file_path: nil)
      expect(error_group.location).to be_nil
    end
  end

  describe "counter_cache" do
    it "increments project error_count" do
      project = create(:project)
      initial_count = project.error_count

      create(:error_group, project: project)
      project.reload

      expect(project.error_count).to eq(initial_count + 1)
    end
  end
end
