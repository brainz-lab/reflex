class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :projects, id: :uuid do |t|
      t.string :platform_project_id, null: false  # prj_xxx from Platform
      t.string :name
      t.string :environment, default: 'live'      # live or test

      t.bigint :error_count, default: 0
      t.bigint :event_count, default: 0

      t.timestamps

      t.index :platform_project_id, unique: true
    end
  end
end
