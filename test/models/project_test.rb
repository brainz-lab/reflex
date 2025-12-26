require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "should be valid with required attributes" do
    project = Project.new(platform_project_id: "prj_123", name: "Test")
    assert project.valid?
  end

  test "requires platform_project_id" do
    project = Project.new(name: "Test")
    assert_not project.valid?
    assert_includes project.errors[:platform_project_id], "can't be blank"
  end

  test "platform_project_id must be unique" do
    create_project(platform_project_id: "prj_unique")

    duplicate = Project.new(platform_project_id: "prj_unique", name: "Duplicate")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:platform_project_id], "has already been taken"
  end

  test "has many error_groups" do
    project = create_project
    assert_respond_to project, :error_groups

    error_group = create_error_group(project: project)
    assert_includes project.error_groups, error_group
  end

  test "has many error_events" do
    project = create_project
    assert_respond_to project, :error_events
  end

  test "destroys associated error_groups when destroyed" do
    project = create_project
    error_group = create_error_group(project: project)

    assert_difference "ErrorGroup.count", -1 do
      project.destroy
    end
  end

  test "find_or_create_for_platform! creates new project" do
    assert_difference "Project.count", 1 do
      project = Project.find_or_create_for_platform!(
        platform_project_id: "prj_new",
        name: "New Project",
        environment: "test"
      )

      assert_equal "prj_new", project.platform_project_id
      assert_equal "New Project", project.name
      assert_equal "test", project.environment
    end
  end

  test "find_or_create_for_platform! finds existing project" do
    existing = create_project(platform_project_id: "prj_existing", name: "Old Name")

    assert_no_difference "Project.count" do
      project = Project.find_or_create_for_platform!(
        platform_project_id: "prj_existing",
        name: "New Name"
      )

      assert_equal existing.id, project.id
      assert_equal "Old Name", project.name # Name should not be updated
    end
  end

  test "defaults environment to live" do
    project = Project.find_or_create_for_platform!(
      platform_project_id: "prj_default"
    )

    assert_equal "live", project.environment
  end

  test "initializes error_count to 0" do
    project = create_project
    assert_equal 0, project.error_count
  end

  test "initializes event_count to 0" do
    project = create_project
    assert_equal 0, project.event_count
  end
end
