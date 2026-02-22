class CreateApiClients < ActiveRecord::Migration[8.1]
  def change
    create_table :api_clients do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.boolean :active, default: true, null: false
      t.text :description
      t.jsonb :allowed_services, default: []

      t.timestamps
    end

    add_index :api_clients, :token_digest, unique: true
  end
end
