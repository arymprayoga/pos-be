class Api::V1::ProductsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_product, only: [ :show, :update, :destroy ]

  def index
    @products = current_company.items
                              .not_deleted
                              .includes(:category, :inventory)

    # Apply filters
    @products = @products.where("name ILIKE ? OR sku ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    @products = @products.where(active: params[:active]) if params[:active].present?
    @products = @products.where(category_id: params[:category_id]) if params[:category_id].present?
    @products = @products.where(track_inventory: params[:track_inventory]) if params[:track_inventory].present?

    # Stock filters
    if params[:stock_status].present?
      case params[:stock_status]
      when "in_stock"
        @products = @products.joins(:inventory).where("inventories.stock > 0")
      when "low_stock"
        @products = @products.joins(:inventory).where("inventories.stock <= inventories.minimum_stock")
      when "out_of_stock"
        @products = @products.joins(:inventory).where("inventories.stock = 0")
      end
    end

    # Price range filter
    @products = @products.where("price >= ?", params[:min_price]) if params[:min_price].present?
    @products = @products.where("price <= ?", params[:max_price]) if params[:max_price].present?

    # Variant filter
    @products = @products.with_variants if params[:has_variants] == "true"

    # Apply sorting
    @products = case params[:sort_by]
    when "name"
                  @products.order(:name)
    when "price"
                  @products.order(:price)
    when "created_at"
                  @products.order(:created_at)
    when "sku"
                  @products.order(:sku)
    else
                  @products.ordered
    end

    # Apply pagination
    page = params[:page]&.to_i || 1
    per_page = [ params[:per_page]&.to_i || 20, 100 ].min

    @products = @products.offset((page - 1) * per_page).limit(per_page)

    total_count = current_company.items.not_deleted.count

    render_success(
      data: @products.map { |product| product_response(product) },
      meta: pagination_meta(page, per_page, total_count)
    )
  end

  def show
    render_success(data: detailed_product_response(@product))
  end

  def create
    @product = current_company.items.build(product_params)
    @product.created_by = current_user.id

    if @product.save
      create_inventory_if_needed
      audit_product_creation
      render_success(
        data: detailed_product_response(@product),
        message: "Product created successfully"
      )
    else
      render_error(
        message: "Failed to create product",
        errors: @product.errors.full_messages
      )
    end
  end

  def update
    @product.assign_attributes(product_params)
    @product.updated_by = current_user.id

    if @product.save
      audit_product_update
      render_success(
        data: detailed_product_response(@product),
        message: "Product updated successfully"
      )
    else
      render_error(
        message: "Failed to update product",
        errors: @product.errors.full_messages
      )
    end
  end

  def destroy
    @product.updated_by = current_user.id
    @product.soft_delete!

    # Also soft delete associated inventory
    @product.inventory&.soft_delete!

    audit_product_deletion

    render_success(
      message: "Product deleted successfully"
    )
  end

  # Variant management endpoints
  def add_variant
    variant_type = params[:variant_type]
    variant_options = params[:variant_options] || []

    if @product.add_variant_type(variant_type, variant_options)
      render_success(
        data: { variants: @product.variants },
        message: "Variant type added successfully"
      )
    else
      render_error(
        message: "Failed to add variant type",
        errors: @product.errors.full_messages
      )
    end
  end

  def remove_variant
    variant_type = params[:variant_type]

    @product.remove_variant_type(variant_type)

    render_success(
      data: { variants: @product.variants },
      message: "Variant type removed successfully"
    )
  end

  def variant_combinations
    render_success(
      data: {
        combinations: @product.variant_combinations,
        total_combinations: @product.variant_combinations.count
      }
    )
  end

  private

  def set_product
    @product = current_company.items.not_deleted.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: "Product not found",
      status: :not_found
    )
  end

  def product_params
    params.require(:product).permit(
      :category_id, :sku, :name, :description, :price, :image_url,
      :active, :track_inventory, :sort_order, variants: {}
    )
  end

  def product_response(product)
    {
      id: product.id,
      category_id: product.category_id,
      category_name: product.category.name,
      sku: product.sku,
      name: product.name,
      description: product.description,
      price: product.price,
      image_url: product.image_url,
      active: product.active,
      track_inventory: product.track_inventory,
      sort_order: product.sort_order,
      has_variants: product.has_variants?,
      variant_types: product.variant_types,
      current_stock: product.current_stock,
      low_stock: product.low_stock?,
      in_stock: product.in_stock?,
      created_at: product.created_at,
      updated_at: product.updated_at
    }
  end

  def detailed_product_response(product)
    response = product_response(product)

    # Add inventory details
    if product.inventory
      response[:inventory] = {
        id: product.inventory.id,
        stock: product.inventory.stock,
        minimum_stock: product.inventory.minimum_stock,
        reserved_stock: product.inventory.reserved_stock,
        available_stock: product.inventory.available_stock,
        last_counted_at: product.inventory.last_counted_at
      }
    end

    # Add variant details
    if product.has_variants?
      response[:variants] = product.variants
      response[:variant_combinations] = product.variant_combinations
    end

    response
  end

  def create_inventory_if_needed
    return unless @product.track_inventory?
    return if @product.inventory.present?

    @product.create_inventory!(
      company_id: current_company.id,
      stock: 0,
      minimum_stock: 0,
      reserved_stock: 0,
      created_by: current_user.id
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

  def audit_product_creation
    UserAction.log_action(
      user_id: current_user.id,
      user_session_id: current_user_session&.id,
      action: "create",
      resource_type: "Item",
      resource_id: @product.id,
      details: {
        product_name: @product.name,
        sku: @product.sku,
        price: @product.price
      },
      success: true
    )
  end

  def audit_product_update
    UserAction.log_action(
      user_id: current_user.id,
      user_session_id: current_user_session&.id,
      action: "update",
      resource_type: "Item",
      resource_id: @product.id,
      details: {
        product_name: @product.name,
        sku: @product.sku,
        changes: @product.previous_changes.except("updated_at", "updated_by")
      },
      success: true
    )
  end

  def audit_product_deletion
    UserAction.log_action(
      user_id: current_user.id,
      user_session_id: current_user_session&.id,
      action: "delete",
      resource_type: "Item",
      resource_id: @product.id,
      details: {
        product_name: @product.name,
        sku: @product.sku
      },
      success: true
    )
  end
end
