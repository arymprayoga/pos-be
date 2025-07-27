class Permission < ApplicationRecord
  acts_as_tenant
  belongs_to :company

  has_and_belongs_to_many :users, join_table: :user_permissions

  validates :name, presence: true, uniqueness: { scope: :company_id }
  validates :resource, presence: true
  validates :action, presence: true

  # Default system permissions
  SYSTEM_PERMISSIONS = {
    # Transaction permissions
    "transactions" => %w[create read update void override_price],
    # Inventory permissions
    "inventory" => %w[create read update delete manage_stock],
    # Report permissions
    "reports" => %w[read export daily_reports monthly_reports],
    # User management permissions
    "users" => %w[create read update delete assign_roles],
    # Company settings permissions
    "settings" => %w[read update manage_payment_methods manage_taxes],
    # Category permissions
    "categories" => %w[create read update delete],
    # Item permissions
    "items" => %w[create read update delete manage_pricing]
  }.freeze

  scope :for_resource, ->(resource) { where(resource: resource) }
  scope :for_action, ->(action) { where(action: action) }
  scope :system_permissions, -> { where(system_permission: true) }

  def self.create_system_permissions_for_company(company)
    SYSTEM_PERMISSIONS.each do |resource, actions|
      actions.each do |action|
        find_or_create_by(
          company: company,
          name: "#{resource}.#{action}",
          resource: resource,
          action: action,
          system_permission: true
        ) do |permission|
          permission.description = generate_permission_description(resource, action)
        end
      end
    end
  end

  def self.generate_permission_description(resource, action)
    action_desc = case action
    when "create" then "Create"
    when "read" then "View"
    when "update" then "Edit"
    when "delete" then "Delete"
    when "void" then "Void"
    when "override_price" then "Override prices for"
    when "manage_stock" then "Manage stock levels for"
    when "export" then "Export"
    when "daily_reports" then "Access daily reports for"
    when "monthly_reports" then "Access monthly reports for"
    when "assign_roles" then "Assign roles to"
    when "manage_payment_methods" then "Manage payment methods"
    when "manage_taxes" then "Manage tax settings"
    when "manage_pricing" then "Manage pricing for"
    else action.humanize
    end

    resource_desc = resource.humanize.downcase
    "#{action_desc} #{resource_desc}"
  end

  def full_name
    "#{resource}.#{action}"
  end

  def system?
    system_permission?
  end
end
