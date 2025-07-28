class Api::V1::CategoriesController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_category, only: [ :show, :update, :destroy ]

  def index
    @categories = current_company.categories
                                .not_deleted
                                .includes(:items)

    # Apply filters
    @categories = @categories.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @categories = @categories.where(active: params[:active]) if params[:active].present?

    # Apply sorting
    @categories = case params[:sort_by]
    when "name"
                   @categories.order(:name)
    when "created_at"
                   @categories.order(:created_at)
    else
                   @categories.ordered
    end

    # Apply pagination
    page = params[:page]&.to_i || 1
    per_page = [ params[:per_page]&.to_i || 20, 100 ].min

    @categories = @categories.offset((page - 1) * per_page).limit(per_page)

    total_count = current_company.categories.not_deleted.count

    render_success(
      data: @categories.map { |category| category_response(category) },
      meta: pagination_meta(page, per_page, total_count)
    )
  end

  def show
    render_success(data: detailed_category_response(@category))
  end

  def create
    @category = current_company.categories.build(category_params)
    @category.created_by = current_user.id

    if @category.save
      audit_category_creation
      render_success(
        data: detailed_category_response(@category),
        message: "Category created successfully"
      )
    else
      render_error(
        message: "Failed to create category",
        errors: @category.errors.full_messages
      )
    end
  end

  def update
    @category.assign_attributes(category_params)
    @category.updated_by = current_user.id

    if @category.save
      audit_category_update
      render_success(
        data: detailed_category_response(@category),
        message: "Category updated successfully"
      )
    else
      render_error(
        message: "Failed to update category",
        errors: @category.errors.full_messages
      )
    end
  end

  def destroy
    @category.updated_by = current_user.id
    @category.soft_delete!

    audit_category_deletion

    render_success(
      message: "Category deleted successfully"
    )
  end

  private

  def set_category
    @category = current_company.categories.not_deleted.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: "Category not found",
      status: :not_found
    )
  end

  def category_params
    params.require(:category).permit(:name, :description, :image_url, :active, :sort_order)
  end

  def category_response(category)
    {
      id: category.id,
      name: category.name,
      description: category.description,
      image_url: category.image_url,
      active: category.active,
      sort_order: category.sort_order,
      items_count: category.items.active.not_deleted.count,
      created_at: category.created_at,
      updated_at: category.updated_at
    }
  end

  def detailed_category_response(category)
    category_response(category).merge(
      items: category.items.active.not_deleted.limit(10).map do |item|
        {
          id: item.id,
          name: item.name,
          sku: item.sku,
          price: item.price,
          active: item.active,
          in_stock: item.in_stock?
        }
      end
    )
  end

  def pagination_meta(page, per_page, total_count)
    {
      current_page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: (total_count.to_f / per_page).ceil
    }
  end

  def audit_category_creation
    UserAction.log_action(
      user_id: current_user.id,
      user_session_id: current_user_session&.id,
      action: "create",
      resource_type: "Category",
      resource_id: @category.id,
      details: { category_name: @category.name },
      success: true
    )
  end

  def audit_category_update
    UserAction.log_action(
      user_id: current_user.id,
      user_session_id: current_user_session&.id,
      action: "update",
      resource_type: "Category",
      resource_id: @category.id,
      details: {
        category_name: @category.name,
        changes: @category.previous_changes.except("updated_at", "updated_by")
      },
      success: true
    )
  end

  def audit_category_deletion
    UserAction.log_action(
      user_id: current_user.id,
      user_session_id: current_user_session&.id,
      action: "delete",
      resource_type: "Category",
      resource_id: @category.id,
      details: { category_name: @category.name },
      success: true
    )
  end
end
