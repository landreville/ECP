class Service < ApplicationRecord
  has_many :credentials, dependent: :destroy

  ADAPTER_TYPES = %w[webdav caldav obsidian gemini].freeze

  validates :name, presence: true, uniqueness: true
  validates :adapter_type, presence: true, inclusion: { in: ADAPTER_TYPES }

  scope :enabled, -> { where(enabled: true) }

  def adapter_class
    case adapter_type
    when "webdav"   then Adapters::WebdavAdapter
    when "caldav"   then Adapters::CaldavAdapter
    when "obsidian" then Adapters::ObsidianAdapter
    when "gemini"   then Adapters::GeminiAdapter
    else raise ArgumentError, "Unknown adapter type: #{adapter_type}"
    end
  end

  def build_adapter
    cred = credentials.first
    adapter_class.new(self, cred)
  end
end
