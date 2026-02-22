class McpSession < ApplicationRecord
  belongs_to :api_client

  SESSION_TTL = 24.hours

  validates :session_id, presence: true, uniqueness: true

  scope :active, -> { where("expires_at > ?", Time.current) }

  def self.create_for_client(api_client, protocol_version:, client_info: {})
    create!(
      api_client: api_client,
      session_id: SecureRandom.uuid,
      protocol_version: protocol_version,
      client_info: client_info,
      last_active_at: Time.current,
      expires_at: SESSION_TTL.from_now
    )
  end

  def touch_activity!
    update_columns(last_active_at: Time.current, expires_at: SESSION_TTL.from_now)
  end

  def expired?
    expires_at < Time.current
  end
end
