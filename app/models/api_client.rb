class ApiClient < ApplicationRecord
  has_many :mcp_sessions, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :token_digest, presence: true

  # Generate a new random API token and return it (plain text, not stored)
  def self.generate_token
    SecureRandom.urlsafe_base64(32)
  end

  def self.create_with_token(attributes = {})
    token = generate_token
    client = new(attributes)
    client.token_digest = Digest::SHA256.hexdigest(token)
    client.save!
    [client, token]
  end

  def self.authenticate(token)
    digest = Digest::SHA256.hexdigest(token)
    find_by(token_digest: digest, active: true)
  end

  def allowed_service?(service_name)
    allowed_services.empty? || allowed_services.include?(service_name.to_s)
  end
end
