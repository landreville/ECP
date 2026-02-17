class Credential < ApplicationRecord
  belongs_to :service

  CREDENTIAL_TYPES = %w[basic_auth bearer_token api_key oauth2].freeze

  # Lockbox encrypts the data column at rest
  # stored in encrypted_data + encrypted_data_iv columns
  encrypts :data

  validates :credential_type, presence: true, inclusion: { in: CREDENTIAL_TYPES }
  validates :service_id, uniqueness: { scope: :credential_type }

  # Credentials are stored as a JSON hash. Use credential_hash for structured access.
  def credential_hash
    return {} if data.blank?
    data.is_a?(String) ? JSON.parse(data) : data
  rescue JSON::ParserError
    {}
  end

  def credential_hash=(hash)
    self.data = hash.to_json
  end

  def [](key)
    credential_hash[key.to_s]
  end
end
