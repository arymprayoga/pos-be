class TaxCalculationService
  # Indonesian PPN (Pajak Pertambahan Nilai) standard rate
  DEFAULT_PPN_RATE = 0.11 # 11%

  class << self
    # Calculate tax for a sales order or individual item
    # @param amount [BigDecimal] - The base amount to calculate tax on
    # @param tax [Tax] - Tax model instance with rate and settings
    # @param tax_inclusive [Boolean] - Whether the amount already includes tax
    # @return [Hash] - Hash with tax details
    def calculate_tax(amount:, tax: nil, tax_inclusive: false, company: nil)
      amount = BigDecimal(amount.to_s)

      # Get tax configuration
      tax_config = get_tax_config(tax, company)
      tax_rate = tax_config[:rate]

      result = if tax_inclusive
        calculate_tax_inclusive(amount, tax_rate)
      else
        calculate_tax_exclusive(amount, tax_rate)
      end

      result.merge(tax_config)
    end

    # Calculate tax for multiple items in a sales order
    # @param items [Array] - Array of sales order items
    # @param company [Company] - Company context for tax settings
    # @return [Hash] - Detailed tax breakdown
    def calculate_order_tax(items:, company:)
      return zero_tax_result unless items.present?

      total_base_amount = BigDecimal("0")
      total_tax_amount = BigDecimal("0")
      item_tax_details = []

      items.each do |item|
        line_total = BigDecimal(item.line_total.to_s)

        # Get tax for this specific item (may have different tax rates)
        item_tax = item.respond_to?(:tax) ? item.tax : nil
        tax_result = calculate_tax(
          amount: line_total,
          tax: item_tax,
          tax_inclusive: company_tax_inclusive?(company),
          company: company
        )

        total_base_amount += tax_result[:base_amount]
        total_tax_amount += tax_result[:tax_amount]

        item_tax_details << {
          item_id: item.id,
          line_total: line_total,
          base_amount: tax_result[:base_amount],
          tax_amount: tax_result[:tax_amount],
          total_with_tax: tax_result[:total_with_tax],
          tax_rate: tax_result[:tax_rate],
          tax_name: tax_result[:tax_name]
        }
      end

      {
        total_base_amount: total_base_amount,
        total_tax_amount: total_tax_amount,
        total_with_tax: total_base_amount + total_tax_amount,
        items: item_tax_details,
        currency: "IDR"
      }
    end

    # Format tax amount for display (Indonesian Rupiah)
    # @param amount [BigDecimal] - Tax amount to format
    # @return [String] - Formatted currency string
    def format_tax_amount(amount)
      formatted = amount.to_i.to_s.reverse.gsub(/...(?=.)/, '\&.').reverse
      "Rp #{formatted}"
    end

    # Validate tax calculation for a sales order
    # @param sales_order [SalesOrder] - The sales order to validate
    # @return [Hash] - Validation result with any discrepancies
    def validate_order_tax(sales_order)
      calculated_tax = calculate_order_tax(
        items: sales_order.sales_order_items,
        company: sales_order.company
      )

      stored_tax = BigDecimal(sales_order.tax_amount.to_s)
      calculated_tax_amount = calculated_tax[:total_tax_amount]

      difference = (stored_tax - calculated_tax_amount).abs
      tolerance = BigDecimal("0.01") # 1 cent tolerance for rounding

      {
        valid: difference <= tolerance,
        stored_tax: stored_tax,
        calculated_tax: calculated_tax_amount,
        difference: difference,
        details: calculated_tax
      }
    end

    private

    # Calculate tax when amount is tax-exclusive (tax added on top)
    def calculate_tax_exclusive(amount, tax_rate)
      base_amount = amount
      tax_amount = (amount * tax_rate).round(2)
      total_with_tax = base_amount + tax_amount

      {
        base_amount: base_amount,
        tax_amount: tax_amount,
        total_with_tax: total_with_tax,
        tax_inclusive: false
      }
    end

    # Calculate tax when amount is tax-inclusive (tax is part of the amount)
    def calculate_tax_inclusive(amount, tax_rate)
      total_with_tax = amount
      base_amount = (amount / (1 + tax_rate)).round(2)
      tax_amount = total_with_tax - base_amount

      {
        base_amount: base_amount,
        tax_amount: tax_amount,
        total_with_tax: total_with_tax,
        tax_inclusive: true
      }
    end

    # Get tax configuration from tax model or company defaults
    def get_tax_config(tax, company)
      if tax.present?
        {
          tax_rate: tax.rate,
          tax_name: tax.name,
          tax_id: tax.id,
          currency: "IDR"
        }
      else
        # Use company default or Indonesian PPN
        default_tax = company&.taxes&.default&.first
        if default_tax
          {
            tax_rate: default_tax.rate,
            tax_name: default_tax.name,
            tax_id: default_tax.id,
            currency: "IDR"
          }
        else
          {
            tax_rate: DEFAULT_PPN_RATE,
            tax_name: "PPN",
            tax_id: nil,
            currency: "IDR"
          }
        end
      end
    end

    # Check if company uses tax-inclusive pricing
    def company_tax_inclusive?(company)
      # Default to tax-exclusive for Indonesian businesses
      # This can be made configurable per company if needed
      company&.tax_inclusive_pricing || false
    end

    # Return zero tax result for empty calculations
    def zero_tax_result
      {
        total_base_amount: BigDecimal("0"),
        total_tax_amount: BigDecimal("0"),
        total_with_tax: BigDecimal("0"),
        items: [],
        currency: "IDR"
      }
    end
  end
end
