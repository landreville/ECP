class CreateCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :credentials do |t|
      t.references :service, null: false, foreign_key: true
      t.string :credential_type, null: false  # basic_auth, bearer_token, api_key, oauth2
      t.text :encrypted_data       # lockbox encrypted JSON blob
      t.string :encrypted_data_iv  # lockbox IV

      t.timestamps
    end

    add_index :credentials, [:service_id, :credential_type], unique: true
  end
end
