# frozen_string_literal: true

require "rails_helper"

RSpec.describe Project, type: :model do
  describe "validations" do
    subject { build(:project) }

    it { is_expected.to validate_presence_of(:platform_project_id) }
    it { is_expected.to validate_uniqueness_of(:platform_project_id) }
  end

  describe "associations" do
    it { is_expected.to have_many(:error_groups).dependent(:destroy) }
    it { is_expected.to have_many(:error_events).dependent(:destroy) }
  end

  describe "has many error_groups" do
    it "includes associated error groups" do
      project = create(:project)
      error_group = create(:error_group, project: project)

      expect(project.error_groups).to include(error_group)
    end
  end

  describe "destroys associated error_groups when destroyed" do
    it "cascades delete" do
      project = create(:project)
      create(:error_group, project: project)

      expect { project.destroy }.to change(ErrorGroup, :count).by(-1)
    end
  end

  describe ".find_or_create_for_platform!" do
    it "creates new project" do
      expect {
        project = Project.find_or_create_for_platform!(
          platform_project_id: "prj_new",
          name: "New Project",
          environment: "test"
        )

        expect(project.platform_project_id).to eq("prj_new")
        expect(project.name).to eq("New Project")
        expect(project.environment).to eq("test")
      }.to change(Project, :count).by(1)
    end

    it "finds existing project" do
      existing = create(:project, platform_project_id: "prj_existing", name: "Old Name")

      expect {
        project = Project.find_or_create_for_platform!(
          platform_project_id: "prj_existing",
          name: "New Name"
        )

        expect(project.id).to eq(existing.id)
        expect(project.name).to eq("Old Name")
      }.not_to change(Project, :count)
    end

    it "defaults environment to live" do
      project = Project.find_or_create_for_platform!(
        platform_project_id: "prj_default"
      )

      expect(project.environment).to eq("live")
    end
  end

  describe "counter caches" do
    it "initializes error_count to 0" do
      project = create(:project)
      expect(project.error_count).to eq(0)
    end

    it "initializes event_count to 0" do
      project = create(:project)
      expect(project.event_count).to eq(0)
    end
  end
end
