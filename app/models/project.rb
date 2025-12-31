class Project < ApplicationRecord
  has_many :error_groups, dependent: :destroy
  has_many :error_events, dependent: :destroy

  validates :platform_project_id, presence: true, uniqueness: true

  def self.find_or_create_for_platform!(platform_project_id:, name: nil, environment: "live")
    find_or_create_by!(platform_project_id: platform_project_id) do |p|
      p.name = name
      p.environment = environment
    end
  end
end
