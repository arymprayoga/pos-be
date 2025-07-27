class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Include concerns for all models
  include Auditable
  include SoftDeletable

  # Multi-tenant scoping for models with company_id
  def self.scoped_to_company(company_id)
    return all unless respond_to?(:column_names) && column_names.include?("company_id")

    where(company_id: company_id)
  end

  # Current company context for multi-tenancy
  def self.current_company
    Thread.current[:current_company]
  end

  def self.current_company=(company)
    Thread.current[:current_company] = company
  end

  # Apply multi-tenant functionality for models
  def self.acts_as_tenant
    extend ClassMethods
    include InstanceMethods

    before_validation :set_company_id, on: :create
  end

  module ClassMethods
    def for_company(company)
      where(company_id: company.id)
    end
  end

  module InstanceMethods
    def belongs_to_current_company?
      return true unless respond_to?(:company_id) && company_id.present?
      return true unless self.class.current_company.present?

      company_id == self.class.current_company.id
    end
  end

  private

  def set_company_id
    return unless respond_to?(:company_id) && self.class.current_company.present?

    self.company_id ||= self.class.current_company.id
  end
end
