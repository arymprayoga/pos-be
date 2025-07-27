module Authorizable
  extend ActiveSupport::Concern

  included do
    has_and_belongs_to_many :permissions, join_table: :user_permissions
  end

  def has_permission?(resource, action)
    return true if owner? # Owners have all permissions

    # Check if user has specific permission
    permissions.exists?(resource: resource.to_s, action: action.to_s) ||
      has_role_permission?(resource, action)
  end

  def has_any_permission?(*permission_pairs)
    permission_pairs.any? do |resource, action|
      has_permission?(resource, action)
    end
  end

  def has_all_permissions?(*permission_pairs)
    permission_pairs.all? do |resource, action|
      has_permission?(resource, action)
    end
  end

  def can?(action, resource_or_class = nil)
    return true if owner?

    if resource_or_class.is_a?(String) || resource_or_class.is_a?(Symbol)
      # Direct permission check: can?(:read, :transactions)
      has_permission?(resource_or_class, action)
    elsif resource_or_class.is_a?(Class)
      # Class-based permission: can?(:read, Transaction)
      resource_name = resource_or_class.name.tableize
      has_permission?(resource_name, action)
    elsif resource_or_class.respond_to?(:class)
      # Instance-based permission: can?(:read, transaction)
      resource_name = resource_or_class.class.name.tableize
      has_permission?(resource_name, action)
    else
      # Default to checking against the action itself
      has_role_permission?(action, "any")
    end
  end

  def cannot?(action, resource_or_class = nil)
    !can?(action, resource_or_class)
  end

  def grant_permission!(resource, action)
    return if has_permission?(resource, action)

    permission = company.permissions.find_by(resource: resource.to_s, action: action.to_s)
    return unless permission

    permissions << permission unless permissions.include?(permission)
  end

  def revoke_permission!(resource, action)
    permission = permissions.find_by(resource: resource.to_s, action: action.to_s)
    permissions.delete(permission) if permission
  end

  def grant_role_permissions!(role_name)
    role_permissions = get_default_permissions_for_role(role_name)

    role_permissions.each do |resource, actions|
      actions.each do |action|
        grant_permission!(resource, action)
      end
    end
  end

  def revoke_all_permissions!
    permissions.clear
  end

  def permission_list
    permissions.includes(:company).map do |permission|
      {
        id: permission.id,
        name: permission.name,
        resource: permission.resource,
        action: permission.action,
        description: permission.description,
        system: permission.system?
      }
    end
  end

  def role_permissions_summary
    grouped_permissions = permissions.group_by(&:resource)

    grouped_permissions.transform_values do |perms|
      perms.map(&:action).sort
    end
  end

  # Authorization helpers for common patterns
  def can_manage_inventory?
    manager? || owner? || has_permission?(:inventory, :manage_stock)
  end

  def can_access_reports?
    manager? || owner? || has_permission?(:reports, :read)
  end

  def can_void_transactions?
    manager? || owner? || has_permission?(:transactions, :void)
  end

  def can_override_prices?
    manager? || owner? || has_permission?(:transactions, :override_price)
  end

  def can_manage_users?
    owner? || has_permission?(:users, :create)
  end

  def can_assign_roles?
    owner? || has_permission?(:users, :assign_roles)
  end

  def can_access_settings?
    manager? || owner? || has_permission?(:settings, :read)
  end

  def can_manage_settings?
    owner? || has_permission?(:settings, :update)
  end

  def can_export_data?
    manager? || owner? || has_permission?(:reports, :export)
  end

  private

  def has_role_permission?(resource, action)
    case role
    when "cashier"
      cashier_permissions.dig(resource.to_s, action.to_s) || false
    when "manager"
      manager_permissions.dig(resource.to_s, action.to_s) ||
        cashier_permissions.dig(resource.to_s, action.to_s) || false
    when "owner"
      true # Owners have all permissions
    else
      false
    end
  end

  def get_default_permissions_for_role(role_name)
    case role_name.to_s
    when "cashier"
      cashier_default_permissions
    when "manager"
      manager_default_permissions
    when "owner"
      owner_default_permissions
    else
      {}
    end
  end

  def cashier_permissions
    {
      "transactions" => { "create" => true, "read" => true },
      "items" => { "read" => true },
      "categories" => { "read" => true },
      "inventory" => { "read" => true }
    }
  end

  def manager_permissions
    {
      "transactions" => { "create" => true, "read" => true, "void" => true, "override_price" => true },
      "items" => { "create" => true, "read" => true, "update" => true, "manage_pricing" => true },
      "categories" => { "create" => true, "read" => true, "update" => true },
      "inventory" => { "read" => true, "update" => true, "manage_stock" => true },
      "reports" => { "read" => true, "export" => true, "daily_reports" => true, "monthly_reports" => true },
      "users" => { "read" => true }
    }
  end

  def cashier_default_permissions
    {
      "transactions" => %w[create read],
      "items" => %w[read],
      "categories" => %w[read],
      "inventory" => %w[read]
    }
  end

  def manager_default_permissions
    {
      "transactions" => %w[create read void override_price],
      "items" => %w[create read update manage_pricing],
      "categories" => %w[create read update],
      "inventory" => %w[read update manage_stock],
      "reports" => %w[read export daily_reports monthly_reports],
      "users" => %w[read]
    }
  end

  def owner_default_permissions
    Permission::SYSTEM_PERMISSIONS.dup
  end
end
