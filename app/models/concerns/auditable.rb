module Auditable
  extend ActiveSupport::Concern

  included do
    before_create :set_created_by
    before_update :set_updated_by
  end

  class_methods do
    def current_user
      Thread.current[:current_user]
    end

    def current_user=(user)
      Thread.current[:current_user] = user
    end
  end

  private

  def set_created_by
    return unless respond_to?(:created_by) && self.class.current_user.present?

    self.created_by ||= self.class.current_user.id
  end

  def set_updated_by
    return unless respond_to?(:updated_by) && self.class.current_user.present?

    self.updated_by = self.class.current_user.id
  end

  def created_by_user
    return nil unless respond_to?(:created_by) && created_by.present?

    User.unscoped.find_by(id: created_by)
  end

  def updated_by_user
    return nil unless respond_to?(:updated_by) && updated_by.present?

    User.unscoped.find_by(id: updated_by)
  end
end
