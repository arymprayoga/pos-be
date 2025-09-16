class Api::V1::TransactionsController < Api::V1::BaseController
  before_action :set_transaction, only: [ :show, :update, :destroy, :void, :receipt ]

  # GET /api/v1/transactions
  def index
    @transactions = current_company.sales_orders
                                  .includes(:payment_method, sales_order_items: :item)
                                  .not_deleted
                                  .page(params[:page])
                                  .per(params[:per_page] || 25)

    # Apply filters
    @transactions = apply_filters(@transactions)

    render_success({
      transactions: @transactions.map { |t| transaction_response(t) },
      pagination: pagination_meta(@transactions)
    })
  end

  # GET /api/v1/transactions/:id
  def show
    render_success(detailed_transaction_response(@transaction))
  end

  # POST /api/v1/transactions
  def create
    authorize_transaction_creation!

    result = TransactionService.create_transaction(
      company: current_company,
      user: current_user,
      items: transaction_params[:items],
      payment_method_id: transaction_params[:payment_method_id],
      paid_amount: transaction_params[:paid_amount],
      options: transaction_options
    )

    if result[:success]
      audit_transaction_creation(result[:sales_order])
      render_success(
        detailed_transaction_response(result[:sales_order]).merge(
          change_amount: result[:change_amount],
          totals: result[:totals]
        ),
        "Transaction created successfully",
        :created
      )
    else
      render_error(result[:error], :unprocessable_entity)
    end
  end

  # PATCH/PUT /api/v1/transactions/:id
  def update
    authorize_transaction_update!

    # Only allow updating certain fields for pending transactions
    unless @transaction.pending?
      render_error("Only pending transactions can be updated", :forbidden)
      return
    end

    if @transaction.update(update_transaction_params)
      audit_transaction_update(@transaction)
      render_success(detailed_transaction_response(@transaction), "Transaction updated successfully")
    else
      render_error("Update failed", :unprocessable_entity, @transaction.errors.full_messages)
    end
  end

  # DELETE /api/v1/transactions/:id
  def destroy
    authorize_transaction_deletion!

    unless @transaction.pending?
      render_error("Only pending transactions can be deleted", :forbidden)
      return
    end

    @transaction.soft_delete!
    audit_transaction_deletion(@transaction)

    render_success({}, "Transaction deleted successfully")
  end

  # POST /api/v1/transactions/:id/void
  def void
    authorize_transaction_void!

    result = TransactionService.void_transaction(
      sales_order: @transaction,
      user: current_user,
      reason: params[:reason]
    )

    if result[:success]
      render_success(detailed_transaction_response(result[:sales_order]), result[:message])
    else
      render_error(result[:error], :unprocessable_entity)
    end
  end

  # GET /api/v1/transactions/:id/receipt
  def receipt
    receipt_data = PaymentService.generate_payment_receipt(@transaction)
    receipt_html = ReceiptService.generate_receipt(@transaction, current_company)

    render_success({
      receipt_data: receipt_data,
      receipt_html: receipt_html
    })
  end

  # POST /api/v1/transactions/:id/refund
  def refund
    authorize_transaction_refund!

    result = TransactionService.process_refund(
      sales_order: @transaction,
      user: current_user,
      items: params[:items],
      reason: params[:reason]
    )

    if result[:success]
      render_success(
        detailed_transaction_response(@transaction).merge(
          refund_amount: result[:refund_amount]
        ),
        result[:message]
      )
    else
      render_error(result[:error], :unprocessable_entity)
    end
  end

  # GET /api/v1/transactions/summary
  def summary
    date_range = parse_date_range
    summary = TransactionService.transaction_summary(
      company: current_company,
      date_range: date_range
    )

    render_success(summary)
  end

  # GET /api/v1/transactions/cash_drawer
  def cash_drawer
    date_range = parse_date_range || (Date.current.beginning_of_day..Date.current.end_of_day)

    sales_orders = current_company.sales_orders
                                 .includes(:payment_method)
                                 .where(created_at: date_range)
                                 .completed

    starting_cash = BigDecimal(params[:starting_cash] || "0")

    cash_summary = PaymentService.cash_drawer_summary(
      sales_orders: sales_orders,
      starting_cash: starting_cash
    )

    render_success(cash_summary)
  end

  private

  def set_transaction
    @transaction = current_company.sales_orders.not_deleted.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Transaction not found", :not_found)
  end

  def transaction_params
    params.require(:transaction).permit(
      :payment_method_id, :paid_amount, :notes, :discount_amount, :tax_id,
      items: [ :item_id, :quantity, :price, :notes ]
    )
  end

  def update_transaction_params
    params.require(:transaction).permit(:notes)
  end

  def transaction_options
    {
      notes: transaction_params[:notes],
      discount_amount: transaction_params[:discount_amount] || 0,
      tax_id: transaction_params[:tax_id]
    }
  end

  def apply_filters(transactions)
    # Status filter
    if params[:status].present?
      transactions = transactions.where(status: params[:status])
    end

    # Date range filter
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date]).beginning_of_day
      end_date = Date.parse(params[:end_date]).end_of_day
      transactions = transactions.where(created_at: start_date..end_date)
    end

    # Payment method filter
    if params[:payment_method_id].present?
      transactions = transactions.where(payment_method_id: params[:payment_method_id])
    end

    # Order number search
    if params[:order_no].present?
      transactions = transactions.where("order_no ILIKE ?", "%#{params[:order_no]}%")
    end

    # Amount range filter
    if params[:min_amount].present?
      transactions = transactions.where("grand_total >= ?", params[:min_amount])
    end

    if params[:max_amount].present?
      transactions = transactions.where("grand_total <= ?", params[:max_amount])
    end

    # Default ordering
    transactions.order(created_at: :desc)
  end

  def parse_date_range
    return nil unless params[:start_date].present? && params[:end_date].present?

    start_date = Date.parse(params[:start_date]).beginning_of_day
    end_date = Date.parse(params[:end_date]).end_of_day
    start_date..end_date
  rescue Date::Error
    nil
  end

  def transaction_response(transaction)
    {
      id: transaction.id,
      order_no: transaction.order_no,
      status: transaction.status,
      sub_total: transaction.sub_total,
      tax_amount: transaction.tax_amount,
      discount_amount: transaction.discount_amount,
      grand_total: transaction.grand_total,
      paid_amount: transaction.paid_amount,
      change_amount: transaction.change_amount,
      payment_method: transaction.payment_method.name,
      total_items: transaction.total_items,
      created_at: transaction.created_at,
      completed_at: transaction.completed_at,
      formatted_total: PaymentService.format_rupiah(transaction.grand_total)
    }
  end

  def detailed_transaction_response(transaction)
    response = transaction_response(transaction)
    response.merge({
      notes: transaction.notes,
      voided_at: transaction.voided_at,
      void_reason: transaction.void_reason,
      items: transaction.sales_order_items.map do |item|
        {
          id: item.id,
          item_id: item.item.id,
          item_name: item.item.name,
          quantity: item.quantity,
          price: item.price,
          tax_amount: item.tax_amount,
          line_total: item.line_total,
          line_total_with_tax: item.line_total_with_tax,
          formatted_price: PaymentService.format_rupiah(item.price),
          formatted_line_total: PaymentService.format_rupiah(item.line_total_with_tax)
        }
      end,
      payment_details: {
        method: transaction.payment_method.name,
        paid_amount: transaction.paid_amount,
        change_amount: transaction.change_amount,
        formatted_paid: PaymentService.format_rupiah(transaction.paid_amount),
        formatted_change: PaymentService.format_rupiah(transaction.change_amount)
      },
      audit_info: {
        created_by: User.find_by(id: transaction.created_by)&.name,
        created_at: transaction.created_at,
        updated_at: transaction.updated_at
      }
    })
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      per_page: collection.limit_value,
      total_pages: collection.total_pages,
      total_count: collection.total_count
    }
  end

  # Authorization methods
  def authorize_transaction_creation!
    unless current_user.can?(:create_transactions)
      render_error("Not authorized to create transactions", :forbidden)
      false
    end
  end

  def authorize_transaction_update!
    unless current_user.can?(:update_transactions)
      render_error("Not authorized to update transactions", :forbidden)
      false
    end
  end

  def authorize_transaction_deletion!
    unless current_user.can?(:delete_transactions)
      render_error("Not authorized to delete transactions", :forbidden)
      false
    end
  end

  def authorize_transaction_void!
    unless current_user.can_void_transactions?
      render_error("Not authorized to void transactions", :forbidden)
      false
    end
  end

  def authorize_transaction_refund!
    unless current_user.can?(:process_refunds)
      render_error("Not authorized to process refunds", :forbidden)
      false
    end
  end

  # Audit logging methods
  def audit_transaction_creation(transaction)
    log_user_action(
      action_type: :transaction,
      resource_type: "SalesOrder",
      resource_id: transaction.id,
      details: {
        action: "created",
        order_no: transaction.order_no,
        amount: transaction.grand_total,
        payment_method: transaction.payment_method.name,
        items_count: transaction.sales_order_items.count
      }
    )
  end

  def audit_transaction_update(transaction)
    log_user_action(
      action_type: :transaction,
      resource_type: "SalesOrder",
      resource_id: transaction.id,
      details: {
        action: "updated",
        order_no: transaction.order_no,
        changes: transaction.previous_changes.except("updated_at")
      }
    )
  end

  def audit_transaction_deletion(transaction)
    log_user_action(
      action_type: :transaction,
      resource_type: "SalesOrder",
      resource_id: transaction.id,
      details: {
        action: "deleted",
        order_no: transaction.order_no,
        amount: transaction.grand_total
      }
    )
  end
end
