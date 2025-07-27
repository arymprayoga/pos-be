# frozen_string_literal: true

ActiveAdmin.register Company do
  permit_params :name, :email, :phone, :address, :currency, :timezone, :active

  # Customize the menu
  menu priority: 2, label: "Companies"

  # Default scope - show only non-deleted companies
  scope :all, default: true
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  # Index page configuration
  index do
    selectable_column
    id_column
    column :name do |company|
      link_to company.name, admin_company_path(company)
    end
    column :email
    column :phone
    column :currency
    column :timezone
    column :active do |company|
      status_tag company.active? ? "Active" : "Inactive",
                 class: company.active? ? "ok" : "error"
    end
    column :users_count do |company|
      company.users.count
    end
    column :sales_orders_count do |company|
      company.sales_orders.count
    end
    column :created_at
    column :deleted_at if params[:scope] == "deleted"
    actions defaults: true do |company|
      if company.deleted?
        link_to "Restore", restore_admin_company_path(company),
                method: :patch, class: "member_link"
      else
        link_to "Delete", delete_admin_company_path(company),
                method: :patch, class: "member_link",
                data: { confirm: "Are you sure you want to delete this company?" }
      end
    end
  end

  # Filters
  filter :name
  filter :email
  filter :active
  filter :currency
  filter :timezone
  filter :created_at
  filter :updated_at

  # Show page configuration
  show do
    attributes_table do
      row :id
      row :name
      row :email
      row :phone
      row :address
      row :currency
      row :timezone
      row :active do |company|
        status_tag company.active? ? "Active" : "Inactive",
                   class: company.active? ? "ok" : "error"
      end
      row :created_at
      row :updated_at
      row :deleted_at if company.deleted?
    end

    panel "Business Metrics" do
      columns do
        column do
          attributes_table_for company do
            row("Total Users") { company.users.count }
            row("Active Users") { company.users.where(active: true).count }
            row("Total Categories") { company.categories.count }
            row("Total Products") { company.items.count }
          end
        end
        column do
          attributes_table_for company do
            row("Total Sales Orders") { company.sales_orders.count }
            row("Active Sessions") { company.user_sessions.active.count }
            row("Payment Methods") { company.payment_methods.count }
            row("Tax Configurations") { company.taxes.count }
          end
        end
      end
    end

    panel "Recent Users" do
      table_for company.users.order(created_at: :desc).limit(5) do
        column :name do |user|
          link_to user.name, admin_user_path(user)
        end
        column :email
        column :role
        column :active do |user|
          status_tag user.active? ? "Active" : "Inactive"
        end
        column :created_at
      end
    end

    panel "Recent Activity" do
      table_for company.user_actions.includes(:user).order(created_at: :desc).limit(10) do
        column :user do |action|
          action.user&.name || "Unknown"
        end
        column :action
        column :resource_type
        column :success do |action|
          status_tag action.success? ? "Success" : "Failed"
        end
        column :created_at
      end
    end
  end

  # Form configuration
  form do |f|
    f.inputs "Company Details" do
      f.input :name, required: true
      f.input :email, required: true
      f.input :phone
      f.input :address, as: :text, rows: 3
      f.input :currency, as: :select,
              collection: [ [ "Indonesian Rupiah (IDR)", "IDR" ], [ "US Dollar (USD)", "USD" ] ],
              selected: "IDR", required: true
      f.input :timezone, as: :select,
              collection: ActiveSupport::TimeZone.all.map { |tz| [ tz.to_s, tz.name ] },
              selected: "Asia/Jakarta", required: true
      f.input :active, as: :boolean, hint: "Inactive companies cannot access the system"
    end
    f.actions
  end

  # Custom actions
  member_action :delete, method: :patch do
    resource.soft_delete!
    redirect_to admin_companies_path, notice: "Company '#{resource.name}' has been deleted."
  end

  member_action :restore, method: :patch do
    resource.update!(deleted_at: nil)
    redirect_to admin_companies_path, notice: "Company '#{resource.name}' has been restored."
  end

  # Batch actions
  batch_action :activate do |ids|
    Company.where(id: ids).update_all(active: true)
    redirect_to admin_companies_path, notice: "#{ids.count} companies have been activated."
  end

  batch_action :deactivate do |ids|
    Company.where(id: ids).update_all(active: false)
    redirect_to admin_companies_path, notice: "#{ids.count} companies have been deactivated."
  end

  batch_action :soft_delete, confirm: "Are you sure you want to delete these companies?" do |ids|
    Company.where(id: ids).update_all(deleted_at: Time.current)
    redirect_to admin_companies_path, notice: "#{ids.count} companies have been deleted."
  end

  # CSV export configuration
  csv do
    column :id
    column :name
    column :email
    column :phone
    column :address
    column :currency
    column :timezone
    column :active
    column :users_count do |company|
      company.users.count
    end
    column :sales_orders_count do |company|
      company.sales_orders.count
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
      end
    end

    def create
      @company = Company.new(permitted_params[:company])
      if @company.save
        redirect_to admin_company_path(@company), notice: "Company was successfully created."
      else
        render :new
      end
    end

    def update
      if resource.update(permitted_params[:company])
        redirect_to admin_company_path(resource), notice: "Company was successfully updated."
      else
        render :edit
      end
    end
  end
end
