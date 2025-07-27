class RefreshToken < ApplicationRecord
  acts_as_tenant
  include Auditable

  belongs_to :user
  belongs_to :company

  validates :token_hash, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :user_id, presence: true
  validates :company_id, presence: true

  scope :active, -> { where(revoked_at: nil) }
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :valid, -> { active.where("expires_at > ?", Time.current) }

  def expired?
    expires_at < Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def token_valid?
    !expired? && !revoked?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def self.cleanup_expired!
    where("expires_at < ? OR revoked_at < ?", Time.current, 30.days.ago).delete_all
  end
end
