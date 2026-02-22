class CreateMcpSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :mcp_sessions do |t|
      t.references :api_client, null: false, foreign_key: true
      t.string :session_id, null: false
      t.string :protocol_version
      t.jsonb :client_info, default: {}
      t.jsonb :server_capabilities, default: {}
      t.datetime :last_active_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :mcp_sessions, :session_id, unique: true
    add_index :mcp_sessions, :expires_at
  end
end
