class TransactionService
  class TransactionError < StandardError; end
  class InsufficientStockError < TransactionError; end
  class InvalidPaymentError < TransactionError; end

  class << self
    # Create a new transaction from cart items
    # @param company [Company] - The company context
    # @param user [User] - The user creating the transaction
    # @param items [Array] - Array of cart items with item_id, quantity, price
    # @param payment_method_id [Integer] - Payment method ID
    # @param paid_amount [BigDecimal] - Amount paid by customer
    # @param options [Hash] - Additional options (discount, notes, etc.)
    # @return [Hash] - Transaction result with order and details
    def create_transaction(company:, user:, items:, payment_method_id:, paid_amount:, options: {})
      return { success: false, error: "No items provided" } if items.blank?

      paid_amount = BigDecimal(paid_amount.to_s)

      ActiveRecord::Base.transaction do
        # Validate payment method
        payment_method = company.payment_methods.active.find_by(id: payment_method_id)
        return { success: false, error: "Invalid payment method" } unless payment_method

        # Generate order number
        order_no = generate_order_number(company)

        # Validate stock availability
        stock_validation = validate_stock_availability(company, items)
        return stock_validation unless stock_validation[:success]

        # Calculate totals
        calculation_result = calculate_order_totals(company, items, options)

        # Validate payment amount
        payment_validation = validate_payment(calculation_result, paid_amount, payment_method)
        return payment_validation unless payment_validation[:success]

        # Create sales order
        sales_order = create_sales_order(
          company: company,
          user: user,
          order_no: order_no,
          payment_method: payment_method,
          calculation_result: calculation_result,
          paid_amount: paid_amount,
          options: options
        )

        # Create sales order items and update inventory
        order_items = create_order_items(sales_order, items, calculation_result)

        # Complete the transaction
        sales_order.update!(status: :completed, completed_at: Time.current)

        # Log transaction
        log_transaction(user, sales_order, "created")

        {
          success: true,
          sales_order: sales_order,
          order_items: order_items,
          totals: calculation_result,
          change_amount: payment_validation[:change_amount]
        }
      end
    rescue InsufficientStockError => e
      { success: false, error: e.message }
    rescue InvalidPaymentError => e
      { success: false, error: e.message }
    rescue ActiveRecord::RecordInvalid => e
      { success: false, error: e.record.errors.full_messages.join(", ") }
    rescue => e
      Rails.logger.error "Transaction creation failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: "Transaction failed. Please try again." }
    end

    # Void a completed transaction
    # @param sales_order [SalesOrder] - The order to void
    # @param user [User] - The user performing the void
    # @param reason [String] - Reason for voiding
    # @return [Hash] - Void result
    def void_transaction(sales_order:, user:, reason: nil)
      return { success: false, error: "Order not found" } unless sales_order
      return { success: false, error: "Order cannot be voided" } unless sales_order.can_be_voided?

      ActiveRecord::Base.transaction do
        # Revert inventory for all items
        sales_order.sales_order_items.each(&:revert_inventory!)

        # Update order status
        sales_order.update!(
          status: :voided,
          voided_at: Time.current,
          void_reason: reason
        )

        # Log void action
        log_transaction(user, sales_order, "voided", { reason: reason })

        {
          success: true,
          message: "Transaction voided successfully",
          sales_order: sales_order
        }
      end
    rescue => e
      Rails.logger.error "Transaction void failed: #{e.message}"
      { success: false, error: "Failed to void transaction" }
    end

    # Process a refund for completed transaction
    # @param sales_order [SalesOrder] - The order to refund
    # @param user [User] - The user processing refund
    # @param items [Array] - Items to refund (optional, defaults to all)
    # @param reason [String] - Refund reason
    # @return [Hash] - Refund result
    def process_refund(sales_order:, user:, items: nil, reason: nil)
      return { success: false, error: "Order not found" } unless sales_order
      return { success: false, error: "Only completed orders can be refunded" } unless sales_order.completed?

      ActiveRecord::Base.transaction do
        refund_items = items || sales_order.sales_order_items
        refund_amount = calculate_refund_amount(refund_items)

        # Create refund record (this would require a Refund model)
        # For now, we'll use the order notes
        sales_order.update!(
          status: :refunded,
          refunded_at: Time.current,
          refund_amount: refund_amount,
          refund_reason: reason
        )

        # Revert inventory for refunded items
        refund_items.each(&:revert_inventory!)

        # Log refund
        log_transaction(user, sales_order, "refunded", {
          amount: refund_amount,
          reason: reason
        })

        {
          success: true,
          refund_amount: refund_amount,
          message: "Refund processed successfully"
        }
      end
    rescue => e
      Rails.logger.error "Refund processing failed: #{e.message}"
      { success: false, error: "Failed to process refund" }
    end

    # Get transaction summary for reporting
    # @param company [Company] - Company context
    # @param date_range [Range] - Date range for summary
    # @param options [Hash] - Additional filters
    # @return [Hash] - Transaction summary
    def transaction_summary(company:, date_range: nil, options: {})
      orders = company.sales_orders.not_deleted
      orders = orders.where(created_at: date_range) if date_range

      completed_orders = orders.completed
      voided_orders = orders.voided

      {
        total_transactions: completed_orders.count,
        total_revenue: completed_orders.sum(:grand_total),
        average_transaction: completed_orders.average(:grand_total)&.round(2) || 0,
        total_items_sold: completed_orders.joins(:sales_order_items).sum("sales_order_items.quantity"),
        voided_transactions: voided_orders.count,
        voided_amount: voided_orders.sum(:grand_total),
        payment_methods: payment_method_breakdown(completed_orders),
        hourly_breakdown: hourly_sales_breakdown(completed_orders),
        currency: "IDR"
      }
    end

    private

    # Generate sequential order number
    def generate_order_number(company)
      date_prefix = Time.current.strftime("%Y%m%d")

      # Find the highest order number for today
      last_order = company.sales_orders
                          .where("order_no LIKE ?", "#{date_prefix}%")
                          .order(:order_no)
                          .last

      if last_order
        last_sequence = last_order.order_no.split("-").last.to_i
        sequence = last_sequence + 1
      else
        sequence = 1
      end

      "#{date_prefix}-#{sequence.to_s.rjust(4, '0')}"
    end

    # Validate stock availability for all items
    def validate_stock_availability(company, items)
      items.each do |item_data|
        item = company.items.find_by(id: item_data[:item_id])
        return { success: false, error: "Item not found: #{item_data[:item_id]}" } unless item

        next unless item.track_inventory?

        available_stock = item.current_stock
        requested_quantity = item_data[:quantity].to_i

        if available_stock < requested_quantity
          return {
            success: false,
            error: "Insufficient stock for #{item.name}. Available: #{available_stock}, Requested: #{requested_quantity}"
          }
        end
      end

      { success: true }
    end

    # Calculate order totals including tax
    def calculate_order_totals(company, items, options = {})
      sub_total = BigDecimal("0")
      tax_amount = BigDecimal("0")

      # Calculate line totals
      items.each do |item_data|
        line_total = BigDecimal(item_data[:price].to_s) * item_data[:quantity].to_i
        sub_total += line_total
      end

      # Apply discount if provided
      discount_amount = BigDecimal(options[:discount_amount].to_s)
      discounted_total = sub_total - discount_amount

      # Calculate tax on discounted amount
      if options[:tax_id].present?
        tax = company.taxes.find_by(id: options[:tax_id])
        tax_calculation = TaxCalculationService.calculate_tax(
          amount: discounted_total,
          tax: tax,
          company: company
        )
        tax_amount = tax_calculation[:tax_amount]
      end

      grand_total = discounted_total + tax_amount

      {
        sub_total: sub_total,
        discount_amount: discount_amount,
        tax_amount: tax_amount,
        grand_total: grand_total,
        currency: "IDR"
      }
    end

    # Validate payment amount
    def validate_payment(calculation_result, paid_amount, payment_method)
      grand_total = calculation_result[:grand_total]

      if paid_amount < grand_total
        return {
          success: false,
          error: "Insufficient payment. Required: #{grand_total}, Paid: #{paid_amount}"
        }
      end

      change_amount = paid_amount - grand_total

      {
        success: true,
        change_amount: change_amount
      }
    end

    # Create sales order record
    def create_sales_order(company:, user:, order_no:, payment_method:, calculation_result:, paid_amount:, options:)
      SalesOrder.create!(
        company: company,
        order_no: order_no,
        payment_method: payment_method,
        sub_total: calculation_result[:sub_total],
        tax_amount: calculation_result[:tax_amount],
        discount_amount: calculation_result[:discount_amount],
        grand_total: calculation_result[:grand_total],
        paid_amount: paid_amount,
        change_amount: paid_amount - calculation_result[:grand_total],
        status: :pending,
        notes: options[:notes],
        created_by: user.id
      )
    end

    # Create order items and update inventory
    def create_order_items(sales_order, items, calculation_result)
      order_items = []

      items.each do |item_data|
        item = sales_order.company.items.find(item_data[:item_id])
        quantity = item_data[:quantity].to_i
        price = BigDecimal(item_data[:price].to_s)

        # Create order item
        order_item = sales_order.sales_order_items.create!(
          item: item,
          quantity: quantity,
          price: price,
          tax_amount: calculate_item_tax(price * quantity, calculation_result)
        )

        # Update inventory if item tracks inventory
        if item.track_inventory?
          update_inventory(item, quantity, sales_order, order_item)
        end

        order_items << order_item
      end

      order_items
    end

    # Calculate tax amount for individual item
    def calculate_item_tax(line_total, calculation_result)
      return BigDecimal("0") if calculation_result[:tax_amount].zero?

      # Proportional tax allocation
      tax_ratio = calculation_result[:tax_amount] / calculation_result[:sub_total]
      (line_total * tax_ratio).round(2)
    end

    # Update inventory and create ledger entry
    def update_inventory(item, quantity, sales_order, order_item)
      # Decrease inventory
      inventory = item.inventory
      inventory.decrement!(:stock, quantity)

      # Create ledger entry
      InventoryLedger.create!(
        company: sales_order.company,
        item: item,
        movement_type: :stock_out,
        quantity: -quantity,
        sales_order_item: order_item,
        remarks: "Sale - Order #{sales_order.order_no}"
      )
    end

    # Calculate refund amount for items
    def calculate_refund_amount(items)
      items.sum { |item| item.line_total_with_tax }
    end

    # Log transaction action
    def log_transaction(user, sales_order, action, details = {})
      UserAction.log_action(
        user: user,
        action_type: :transaction,
        resource_type: "SalesOrder",
        resource_id: sales_order.id,
        details: {
          action: action,
          order_no: sales_order.order_no,
          amount: sales_order.grand_total
        }.merge(details)
      )
    end

    # Payment method breakdown for reporting
    def payment_method_breakdown(orders)
      orders.joins(:payment_method)
            .group("payment_methods.name")
            .sum(:grand_total)
    end

    # Hourly sales breakdown
    def hourly_sales_breakdown(orders)
      orders.group("DATE_TRUNC('hour', created_at)")
            .sum(:grand_total)
    end
  end
end
