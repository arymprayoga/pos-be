module SoftDeletable
  extend ActiveSupport::Concern

  included do
    scope :not_deleted, -> { where(deleted_at: nil) }
    scope :deleted, -> { where.not(deleted_at: nil) }
  end

  def soft_delete!
    return false if deleted?

    update!(deleted_at: Time.current)
  end

  def restore!
    return false unless deleted?

    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  def active?
    !deleted?
  end

  # Override destroy to perform soft delete instead
  def destroy
    soft_delete!
  end

  def destroy!
    soft_delete!
  end

  # Actually delete the record from database
  def really_destroy!
    super.destroy!
  end
end
