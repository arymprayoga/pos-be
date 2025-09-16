class PaymentService
  class PaymentError < StandardError; end
  class InsufficientFundsError < PaymentError; end
  class InvalidDenominationError < PaymentError; end

  # Indonesian Rupiah denominations for cash handling
  RUPIAH_DENOMINATIONS = [
    100_000, 50_000, 20_000, 10_000, 5_000, 2_000, 1_000, 500, 200, 100
  ].freeze

  class << self
    # Calculate change for cash payment
    # @param total_amount [BigDecimal] - Total amount due
    # @param paid_amount [BigDecimal] - Amount paid by customer
    # @return [Hash] - Change calculation result
    def calculate_change(total_amount:, paid_amount:)
      total = BigDecimal(total_amount.to_s)
      paid = BigDecimal(paid_amount.to_s)

      return { success: false, error: "Insufficient payment" } if paid < total

      change_amount = paid - total
      change_breakdown = calculate_denomination_breakdown(change_amount)

      {
        success: true,
        change_amount: change_amount,
        change_breakdown: change_breakdown,
        formatted_change: format_rupiah(change_amount)
      }
    end

    # Validate payment amount and method
    # @param payment_method [PaymentMethod] - Payment method being used
    # @param amount_due [BigDecimal] - Total amount due
    # @param amount_paid [BigDecimal] - Amount being paid
    # @param options [Hash] - Additional payment options
    # @return [Hash] - Validation result
    def validate_payment(payment_method:, amount_due:, amount_paid:, options: {})
      amount_due = BigDecimal(amount_due.to_s)
      amount_paid = BigDecimal(amount_paid.to_s)

      # Basic amount validation
      if amount_paid < amount_due
        return {
          success: false,
          error: "Insufficient payment",
          shortfall: amount_due - amount_paid
        }
      end

      # Payment method specific validations
      validation_result = case payment_method.name.downcase
      when "cash", "tunai"
        validate_cash_payment(amount_due, amount_paid, options)
      when "card", "kartu"
        validate_card_payment(amount_due, amount_paid, options)
      when "digital", "e-wallet"
        validate_digital_payment(amount_due, amount_paid, options)
      else
        validate_generic_payment(amount_due, amount_paid, options)
      end

      if validation_result[:success]
        change_result = calculate_change(
          total_amount: amount_due,
          paid_amount: amount_paid
        )
        validation_result.merge(change_result)
      else
        validation_result
      end
    end

    # Process multiple payment methods (split payment)
    # @param total_amount [BigDecimal] - Total amount due
    # @param payments [Array] - Array of payment method details
    # @return [Hash] - Split payment result
    def process_split_payment(total_amount:, payments:)
      total = BigDecimal(total_amount.to_s)
      total_paid = BigDecimal("0")
      processed_payments = []

      payments.each do |payment_data|
        payment_method = PaymentMethod.find(payment_data[:payment_method_id])
        amount = BigDecimal(payment_data[:amount].to_s)

        validation = validate_payment(
          payment_method: payment_method,
          amount_due: amount,
          amount_paid: amount,
          options: payment_data[:options] || {}
        )

        unless validation[:success]
          return {
            success: false,
            error: "Payment validation failed for #{payment_method.name}: #{validation[:error]}"
          }
        end

        total_paid += amount
        processed_payments << {
          payment_method: payment_method,
          amount: amount,
          formatted_amount: format_rupiah(amount)
        }
      end

      if total_paid < total
        return {
          success: false,
          error: "Total payments insufficient",
          shortfall: total - total_paid,
          formatted_shortfall: format_rupiah(total - total_paid)
        }
      end

      change_amount = total_paid - total

      {
        success: true,
        total_paid: total_paid,
        change_amount: change_amount,
        payments: processed_payments,
        change_breakdown: calculate_denomination_breakdown(change_amount)
      }
    end

    # Calculate cash drawer summary
    # @param sales_orders [ActiveRecord::Relation] - Sales orders for period
    # @param starting_cash [BigDecimal] - Cash drawer starting amount
    # @return [Hash] - Cash drawer summary
    def cash_drawer_summary(sales_orders:, starting_cash: BigDecimal("0"))
      cash_sales = sales_orders.joins(:payment_method)
                              .where(payment_methods: { name: [ "Cash", "Tunai" ] })

      total_cash_sales = cash_sales.sum(:grand_total)
      total_change_given = cash_sales.sum(:change_amount)
      net_cash_received = total_cash_sales - total_change_given

      expected_cash = starting_cash + net_cash_received

      {
        starting_cash: starting_cash,
        total_cash_sales: total_cash_sales,
        total_change_given: total_change_given,
        net_cash_received: net_cash_received,
        expected_cash: expected_cash,
        formatted_expected_cash: format_rupiah(expected_cash),
        transaction_count: cash_sales.count,
        currency: "IDR"
      }
    end

    # Generate payment receipt data
    # @param sales_order [SalesOrder] - The completed sales order
    # @return [Hash] - Payment receipt data
    def generate_payment_receipt(sales_order)
      {
        order_no: sales_order.order_no,
        payment_method: sales_order.payment_method.name,
        sub_total: sales_order.sub_total,
        tax_amount: sales_order.tax_amount,
        discount_amount: sales_order.discount_amount,
        grand_total: sales_order.grand_total,
        paid_amount: sales_order.paid_amount,
        change_amount: sales_order.change_amount,
        formatted_amounts: {
          sub_total: format_rupiah(sales_order.sub_total),
          tax_amount: format_rupiah(sales_order.tax_amount),
          discount_amount: format_rupiah(sales_order.discount_amount),
          grand_total: format_rupiah(sales_order.grand_total),
          paid_amount: format_rupiah(sales_order.paid_amount),
          change_amount: format_rupiah(sales_order.change_amount)
        },
        change_breakdown: calculate_denomination_breakdown(sales_order.change_amount),
        payment_time: sales_order.completed_at || sales_order.created_at
      }
    end

    # Round amount to nearest valid denomination
    # @param amount [BigDecimal] - Amount to round
    # @return [BigDecimal] - Rounded amount
    def round_to_denomination(amount)
      amount_cents = (amount * 100).to_i

      # Round to nearest 100 (1 Rupiah)
      rounded_cents = ((amount_cents + 50) / 100) * 100

      BigDecimal(rounded_cents.to_s) / 100
    end

    # Format amount in Indonesian Rupiah
    # @param amount [BigDecimal] - Amount to format
    # @return [String] - Formatted currency string
    def format_rupiah(amount)
      return "Rp 0" if amount.zero?

      amount_str = amount.to_i.to_s
      # Add thousand separators
      formatted = amount_str.reverse.gsub(/(\d{3})(?=\d)/, '\1.').reverse
      "Rp #{formatted}"
    end

    private

    # Calculate denomination breakdown for change
    def calculate_denomination_breakdown(amount)
      return [] if amount.zero?

      breakdown = []
      remaining = amount.to_i

      RUPIAH_DENOMINATIONS.each do |denomination|
        if remaining >= denomination
          count = remaining / denomination
          breakdown << {
            denomination: denomination,
            count: count,
            total: denomination * count,
            formatted_denomination: format_rupiah(denomination),
            formatted_total: format_rupiah(denomination * count)
          }
          remaining -= denomination * count
        end
      end

      breakdown
    end

    # Validate cash payment
    def validate_cash_payment(amount_due, amount_paid, options)
      # Check for reasonable denominations
      if options[:validate_denominations] && !valid_cash_amount?(amount_paid)
        return {
          success: false,
          error: "Invalid cash denomination"
        }
      end

      # Ensure exact or overpayment for cash
      if amount_paid < amount_due
        return {
          success: false,
          error: "Insufficient cash payment"
        }
      end

      { success: true }
    end

    # Validate card payment
    def validate_card_payment(amount_due, amount_paid, options)
      # Card payments should be exact amount
      if amount_paid != amount_due
        return {
          success: false,
          error: "Card payment must be exact amount"
        }
      end

      # Validate card details if provided
      if options[:card_number] && !valid_card_format?(options[:card_number])
        return {
          success: false,
          error: "Invalid card number format"
        }
      end

      { success: true }
    end

    # Validate digital payment (e-wallet, mobile banking)
    def validate_digital_payment(amount_due, amount_paid, options)
      # Digital payments should be exact amount
      if amount_paid != amount_due
        return {
          success: false,
          error: "Digital payment must be exact amount"
        }
      end

      # Validate transaction reference if provided
      if options[:reference_number].blank?
        return {
          success: false,
          error: "Digital payment requires reference number"
        }
      end

      { success: true }
    end

    # Generic payment validation
    def validate_generic_payment(amount_due, amount_paid, options)
      if amount_paid < amount_due
        return {
          success: false,
          error: "Insufficient payment amount"
        }
      end

      { success: true }
    end

    # Check if cash amount uses valid denominations
    def valid_cash_amount?(amount)
      amount_cents = (amount * 100).to_i
      # Check if amount is divisible by smallest denomination (100 cents = 1 Rupiah)
      amount_cents % 100 == 0
    end

    # Basic card number format validation
    def valid_card_format?(card_number)
      # Remove spaces and dashes
      cleaned = card_number.to_s.gsub(/[\s\-]/, "")
      # Check if it's numeric and proper length
      cleaned.match?(/^\d{13,19}$/)
    end
  end
end
