class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.string :adapter_type, null: false  # webdav, caldav, obsidian, gemini
      t.string :base_url
      t.boolean :enabled, default: true, null: false
      t.text :description
      t.jsonb :config, default: {}  # adapter-specific non-sensitive config

      t.timestamps
    end

    add_index :services, :name, unique: true
    add_index :services, :adapter_type
  end
end
