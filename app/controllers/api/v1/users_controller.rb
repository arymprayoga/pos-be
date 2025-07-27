class Api::V1::UsersController < Api::V1::BaseController
  include AuditLogging

  before_action :authenticate_user!
  before_action :set_user, only: [ :show, :update, :destroy, :change_role, :manage_permissions, :sessions ]
  before_action :authorize_user_management!, except: [ :show, :sessions ]
  before_action :authorize_self_or_management!, only: [ :show, :sessions ]

  def index
    authorize_action!(:read, :users)

    @users = current_company.users
                           .not_deleted
                           .includes(:permissions)
                           .page(params[:page])
                           .per(params[:per_page] || 25)

    if params[:role].present?
      @users = @users.where(role: params[:role])
    end

    if params[:active].present?
      @users = @users.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
    end

    add_audit_details(
      total_users: @users.total_count,
      filters: params.slice(:role, :active, :page, :per_page)
    )

    render_success(
      data: @users.map { |user| user_response(user) },
      meta: pagination_meta(@users)
    )
  end

  def show
    render_success(data: detailed_user_response(@user))
  end

  def create
    authorize_action!(:create, :users)

    @user = current_company.users.build(user_params)
    @user.created_by = current_user.id

    if @user.save
      # Set default permissions for role
      @user.grant_role_permissions!(@user.role)

      # Create system permissions for company if needed
      Permission.create_system_permissions_for_company(current_company)

      audit_user_creation(@user)

      render_success(
        data: detailed_user_response(@user),
        message: "User created successfully"
      )
    else
      log_failed_action("User creation failed: #{@user.errors.full_messages.join(', ')}")
      render_error(
        message: "Failed to create user",
        errors: @user.errors.full_messages
      )
    end
  end

  def update
    authorize_action!(:update, :users)

    old_attributes = @user.attributes.dup

    if @user.update(user_params.except(:role))
      audit_user_update(@user, old_attributes)

      render_success(
        data: detailed_user_response(@user),
        message: "User updated successfully"
      )
    else
      log_failed_action("User update failed: #{@user.errors.full_messages.join(', ')}")
      render_error(
        message: "Failed to update user",
        errors: @user.errors.full_messages
      )
    end
  end

  def destroy
    authorize_action!(:delete, :users)

    if @user == current_user
      return render_error(message: "Cannot delete your own account")
    end

    if @user.soft_delete!
      # Terminate all user sessions
      SessionManager.new(@user).terminate_all_sessions

      audit_user_deletion(@user)

      render_success(message: "User deleted successfully")
    else
      log_failed_action("User deletion failed")
      render_error(message: "Failed to delete user")
    end
  end

  def change_role
    authorize_action!(:assign_roles, :users)

    if @user == current_user && params[:role] != current_user.role
      return render_error(message: "Cannot change your own role")
    end

    old_role = @user.role
    new_role = params[:role]

    # Validate role
    unless User.roles.key?(new_role)
      return render_error(message: "Invalid role specified")
    end

    # Update role and permissions
    @user.transaction do
      @user.update!(role: new_role, updated_by: current_user.id)

      # Clear existing permissions and set new role permissions
      @user.revoke_all_permissions!
      @user.grant_role_permissions!(new_role)
    end

    audit_role_change(@user.id, old_role, new_role)

    render_success(
      data: detailed_user_response(@user),
      message: "User role updated successfully"
    )
  rescue ActiveRecord::RecordInvalid => e
    log_failed_action("Role change failed: #{e.message}")
    render_error(message: "Failed to change user role", errors: [ e.message ])
  end

  def manage_permissions
    authorize_action!(:assign_roles, :users)

    permission_changes = params[:permissions] || {}
    granted_permissions = []
    revoked_permissions = []

    @user.transaction do
      permission_changes.each do |resource, actions|
        actions.each do |action, granted|
          if ActiveModel::Type::Boolean.new.cast(granted)
            @user.grant_permission!(resource, action)
            granted_permissions << "#{resource}.#{action}"
          else
            @user.revoke_permission!(resource, action)
            revoked_permissions << "#{resource}.#{action}"
          end
        end
      end
    end

    audit_permission_change(
      @user.id,
      {
        granted: granted_permissions,
        revoked: revoked_permissions
      }
    )

    render_success(
      data: {
        user: detailed_user_response(@user),
        changes: {
          granted: granted_permissions,
          revoked: revoked_permissions
        }
      },
      message: "User permissions updated successfully"
    )
  end

  def sessions
    session_manager = SessionManager.new(@user)

    sessions_data = session_manager.list_active_sessions
    analytics = session_manager.session_analytics

    add_audit_details(
      session_count: sessions_data.length,
      viewed_user_id: @user.id
    )

    render_success(
      data: {
        active_sessions: sessions_data,
        analytics: analytics
      }
    )
  end

  def terminate_session
    authorize_action!(:update, :users)

    session_manager = SessionManager.new(@user)

    if session_manager.terminate_session(params[:session_token])
      add_audit_details(
        terminated_session: params[:session_token],
        target_user_id: @user.id
      )

      render_success(message: "Session terminated successfully")
    else
      render_error(message: "Session not found or already terminated")
    end
  end

  private

  def set_user
    @user = current_company.users.not_deleted.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(message: "User not found", status: :not_found)
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role, :active)
  end

  def authorize_user_management!
    unless current_user.can_manage_users?
      render_error(message: "Insufficient permissions", status: :forbidden)
    end
  end

  def authorize_self_or_management!
    unless @user == current_user || current_user.can_manage_users?
      render_error(message: "Insufficient permissions", status: :forbidden)
    end
  end

  def authorize_action!(action, resource)
    unless current_user.can?(action, resource)
      render_error(message: "Insufficient permissions for #{action} #{resource}", status: :forbidden)
    end
  end

  def user_response(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      active: user.active?,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end

  def detailed_user_response(user)
    user_response(user).merge(
      permissions: user.permission_list,
      role_permissions: user.role_permissions_summary,
      can_manage_inventory: user.can_manage_inventory?,
      can_access_reports: user.can_access_reports?,
      can_void_transactions: user.can_void_transactions?,
      can_override_prices: user.can_override_prices?,
      can_manage_users: user.can_manage_users?
    )
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end

  def audit_user_creation(user)
    add_audit_details(
      created_user_id: user.id,
      created_user_email: user.email,
      created_user_role: user.role,
      sensitive: true
    )
  end

  def audit_user_update(user, old_attributes)
    changes = {}
    user.previous_changes.each do |attr, (old_val, new_val)|
      next if attr.in?(%w[updated_at updated_by])
      changes[attr] = { from: old_val, to: new_val }
    end

    add_audit_details(
      updated_user_id: user.id,
      changes: changes,
      sensitive: true
    )
  end

  def audit_user_deletion(user)
    add_audit_details(
      deleted_user_id: user.id,
      deleted_user_email: user.email,
      deleted_user_role: user.role,
      sensitive: true
    )
  end
end
