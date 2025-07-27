# frozen_string_literal: true

ActiveAdmin.register User do
  permit_params :name, :email, :password, :password_confirmation, :company_id, :role, :active

  # Customize the menu
  menu priority: 3, label: "Users"

  # Scopes for filtering
  scope :all, default: true
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :cashiers, -> { where(role: "cashier") }
  scope :managers, -> { where(role: "manager") }
  scope :owners, -> { where(role: "owner") }
  scope :deleted, -> { where.not(deleted_at: nil) }

  # Index page configuration
  index do
    selectable_column
    id_column
    column :name do |user|
      link_to user.name, admin_user_path(user)
    end
    column :email
    column :company do |user|
      link_to user.company.name, admin_company_path(user.company) if user.company
    end
    column :role do |user|
      status_tag user.role.humanize,
                 class: case user.role
                        when "owner" then "ok"
                        when "manager" then "warning"
                        when "cashier" then "no"
                        else "default"
                        end
    end
    column :active do |user|
      status_tag user.active? ? "Active" : "Inactive",
                 class: user.active? ? "ok" : "error"
    end
    column :session_count do |user|
      user.session_count
    end
    column :last_login_at do |user|
      user.last_login_at&.strftime("%Y-%m-%d %H:%M")
    end
    column :created_at
    column :deleted_at if params[:scope] == "deleted"
    actions defaults: true do |user|
      if user.deleted?
        link_to "Restore", restore_admin_user_path(user),
                method: :patch, class: "member_link"
      else
        link_to "Deactivate", deactivate_admin_user_path(user),
                method: :patch, class: "member_link",
                data: { confirm: "Are you sure?" } if user.active?
        link_to "Activate", activate_admin_user_path(user),
                method: :patch, class: "member_link" unless user.active?
        link_to "Delete", delete_admin_user_path(user),
                method: :patch, class: "member_link",
                data: { confirm: "Are you sure you want to delete this user?" } unless user.deleted?
        link_to "Sessions", sessions_admin_user_path(user),
                class: "member_link"
      end
    end
  end

  # Filters
  filter :name
  filter :email
  filter :company, as: :select, collection: -> { Company.where(deleted_at: nil).order(:name) }
  filter :role, as: :select, collection: User.roles.map { |role, _| [ role.humanize, role ] }
  filter :active
  filter :created_at
  filter :updated_at

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :name
      row :email
      row :company do |user|
        link_to user.company.name, admin_company_path(user.company) if user.company
      end
      row :role do |user|
        status_tag user.role.humanize,
                   class: case user.role
                          when "owner" then "ok"
                          when "manager" then "warning"
                          when "cashier" then "no"
                          end
      end
      row :active do |user|
        status_tag user.active? ? "Active" : "Inactive",
                   class: user.active? ? "ok" : "error"
      end
      row :created_at
      row :updated_at
      row :deleted_at if user.deleted?
    end

    panel "Permission Summary" do
      permissions = user.permission_summary
      attributes_table_for user do
        row("Role") { permissions[:role].humanize }
        row("Custom Permissions") { permissions[:custom_permissions] }
        row("Can Manage Inventory") { status_tag permissions[:can_manage_inventory] }
        row("Can Access Reports") { status_tag permissions[:can_access_reports] }
        row("Can Void Transactions") { status_tag permissions[:can_void_transactions] }
        row("Can Override Prices") { status_tag permissions[:can_override_prices] }
        row("Can Manage Users") { status_tag permissions[:can_manage_users] }
        row("Can Assign Roles") { status_tag permissions[:can_assign_roles] }
        row("Can Access Settings") { status_tag permissions[:can_access_settings] }
        row("Can Manage Settings") { status_tag permissions[:can_manage_settings] }
      end
    end

    panel "Activity Summary (Last 7 Days)" do
      activity = user.activity_summary(7)
      columns do
        column do
          attributes_table_for user do
            row("Total Actions") { activity[:total_actions] }
            row("Successful Actions") { activity[:successful_actions] }
            row("Failed Actions") { activity[:failed_actions] }
            row("Sensitive Actions") { activity[:sensitive_actions] }
          end
        end
        column do
          attributes_table_for user do
            row("Login Count") { activity[:login_count] }
            row("Last Login") { activity[:last_login]&.strftime("%Y-%m-%d %H:%M") }
            row("Last Activity") { activity[:last_activity]&.strftime("%Y-%m-%d %H:%M") }
            row("Active Sessions") { activity[:active_sessions] }
          end
        end
      end
    end

    panel "Security Summary" do
      security = user.security_summary
      attributes_table_for user do
        row("Password Last Changed") { security[:password_last_changed]&.strftime("%Y-%m-%d %H:%M") }
        row("Active Sessions") { security[:active_sessions] }
        row("Failed Login Attempts (24h)") { security[:failed_login_attempts] }
        row("Recent IP Addresses") { security[:recent_ip_addresses].join(", ") if security[:recent_ip_addresses].any? }
      end
    end

    panel "Recent Actions" do
      table_for user.recent_actions(limit: 10) do
        column :action
        column :resource_type
        column :resource_id
        column :success do |action|
          status_tag action.success? ? "Success" : "Failed"
        end
        column :ip_address
        column :created_at
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs "User Details" do
      f.input :name, required: true
      f.input :email, required: true
      f.input :company, as: :select,
              collection: Company.where(deleted_at: nil, active: true).order(:name),
              required: true
      f.input :role, as: :select,
              collection: User.roles.map { |role, _| [ role.humanize, role ] },
              required: true,
              hint: "Owner: Full access, Manager: Inventory + Reports, Cashier: Basic POS"
      f.input :active, as: :boolean, hint: "Inactive users cannot login"
    end

    if f.object.new_record?
      f.inputs "Password" do
        f.input :password, required: true
        f.input :password_confirmation, required: true
      end
    else
      f.inputs "Change Password (leave blank to keep current)" do
        f.input :password
        f.input :password_confirmation
      end
    end

    f.actions
  end

  # Custom member actions
  member_action :activate, method: :patch do
    resource.activate!
    redirect_to admin_user_path(resource), notice: "User '#{resource.name}' has been activated."
  end

  member_action :deactivate, method: :patch do
    resource.deactivate!
    redirect_to admin_user_path(resource), notice: "User '#{resource.name}' has been deactivated."
  end

  member_action :delete, method: :patch do
    resource.soft_delete!
    redirect_to admin_users_path, notice: "User '#{resource.name}' has been deleted."
  end

  member_action :restore, method: :patch do
    resource.restore!
    redirect_to admin_users_path, notice: "User '#{resource.name}' has been restored."
  end

  member_action :sessions, method: :get do
    @sessions = resource.user_sessions.order(created_at: :desc).limit(20)
    render "admin/users/sessions"
  end

  member_action :terminate_session, method: :patch do
    session = resource.user_sessions.find(params[:session_id])
    session.logout!
    redirect_to sessions_admin_user_path(resource), notice: "Session terminated."
  end

  # Batch actions
  batch_action :activate do |ids|
    User.where(id: ids).each(&:activate!)
    redirect_to admin_users_path, notice: "#{ids.count} users have been activated."
  end

  batch_action :deactivate do |ids|
    User.where(id: ids).each(&:deactivate!)
    redirect_to admin_users_path, notice: "#{ids.count} users have been deactivated."
  end

  batch_action :change_role, form: {
    role: User.roles.map { |role, _| [ role.humanize, role ] }
  } do |ids, inputs|
    User.where(id: ids).update_all(role: inputs[:role])
    redirect_to admin_users_path, notice: "#{ids.count} users' roles have been changed to #{inputs[:role].humanize}."
  end

  batch_action :soft_delete, confirm: "Are you sure you want to delete these users?" do |ids|
    User.where(id: ids).each(&:soft_delete!)
    redirect_to admin_users_path, notice: "#{ids.count} users have been deleted."
  end

  # CSV export configuration
  csv do
    column :id
    column :name
    column :email
    column :company do |user|
      user.company&.name
    end
    column :role
    column :active
    column :session_count do |user|
      user.session_count
    end
    column :last_login_at do |user|
      user.last_login_at
    end
    column :created_at
    column :updated_at
    column :deleted_at
  end

  # Controller customization
  controller do
    def scoped_collection
      if params[:scope] == "deleted"
        end_of_association_chain.where.not(deleted_at: nil)
      else
        end_of_association_chain.where(deleted_at: nil)
      end.includes(:company)
    end

    def create
      @user = User.new(permitted_params[:user])
      if @user.save
        redirect_to admin_user_path(@user), notice: "User was successfully created."
      else
        render :new
      end
    end

    def update
      user_params = permitted_params[:user]
      # Remove empty password fields
      if user_params[:password].blank?
        user_params.delete(:password)
        user_params.delete(:password_confirmation)
      end

      if resource.update(user_params)
        redirect_to admin_user_path(resource), notice: "User was successfully updated."
      else
        render :edit
      end
    end
  end
end
