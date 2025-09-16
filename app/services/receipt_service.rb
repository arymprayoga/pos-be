class ReceiptService
  class << self
    # Generate HTML receipt for a sales order
    # @param sales_order [SalesOrder] - The completed sales order
    # @param company [Company] - Company information for customization
    # @param options [Hash] - Additional receipt options
    # @return [String] - HTML receipt content
    def generate_receipt(sales_order, company, options = {})
      template_data = build_receipt_data(sales_order, company, options)

      if options[:template] == "thermal"
        generate_thermal_receipt(template_data)
      else
        generate_standard_receipt(template_data)
      end
    end

    # Generate receipt data for external rendering
    # @param sales_order [SalesOrder] - The sales order
    # @param company [Company] - Company context
    # @return [Hash] - Receipt data structure
    def build_receipt_data(sales_order, company, options = {})
      payment_data = PaymentService.generate_payment_receipt(sales_order)

      {
        company: company_info(company),
        order: order_info(sales_order),
        items: items_info(sales_order.sales_order_items),
        payment: payment_data,
        totals: totals_info(sales_order),
        footer: footer_info(company, options),
        metadata: {
          printed_at: Time.current,
          cashier: User.find_by(id: sales_order.created_by)&.name || "System",
          receipt_type: options[:template] || "standard"
        }
      }
    end

    # Generate receipt for email/PDF export
    # @param sales_order [SalesOrder] - The sales order
    # @param company [Company] - Company context
    # @param format [Symbol] - Export format (:pdf, :email)
    # @return [String] - Formatted receipt content
    def generate_export_receipt(sales_order, company, format = :pdf)
      template_data = build_receipt_data(sales_order, company, {
        template: "export",
        format: format
      })

      case format
      when :pdf
        generate_pdf_receipt(template_data)
      when :email
        generate_email_receipt(template_data)
      else
        generate_standard_receipt(template_data)
      end
    end

    # Validate receipt data completeness
    # @param sales_order [SalesOrder] - The sales order to validate
    # @return [Hash] - Validation result
    def validate_receipt_data(sales_order)
      errors = []

      errors << "Order number missing" if sales_order.order_no.blank?
      errors << "Payment method missing" if sales_order.payment_method.blank?
      errors << "No items in order" if sales_order.sales_order_items.empty?
      errors << "Invalid totals" if sales_order.grand_total <= 0

      {
        valid: errors.empty?,
        errors: errors
      }
    end

    # Generate receipt number for tracking
    # @param sales_order [SalesOrder] - The sales order
    # @return [String] - Receipt tracking number
    def generate_receipt_number(sales_order)
      "R#{sales_order.order_no}"
    end

    private

    # Generate standard HTML receipt
    def generate_standard_receipt(data)
      <<~HTML
        <!DOCTYPE html>
        <html lang="id">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Receipt - #{data[:order][:order_no]}</title>
            <style>
                body {#{' '}
                    font-family: 'Courier New', monospace;#{' '}
                    margin: 0;#{' '}
                    padding: 20px;#{' '}
                    background: white;
                    color: black;
                }
                .receipt {#{' '}
                    max-width: 400px;#{' '}
                    margin: 0 auto;#{' '}
                    border: 1px solid #ddd;#{' '}
                    padding: 20px;
                }
                .header { text-align: center; margin-bottom: 20px; }
                .company-name { font-size: 18px; font-weight: bold; }
                .company-info { font-size: 12px; margin-top: 5px; }
                .order-info { margin: 15px 0; font-size: 12px; }
                .items { border-top: 1px dashed #333; border-bottom: 1px dashed #333; padding: 10px 0; }
                .item { display: flex; justify-content: space-between; margin: 5px 0; font-size: 12px; }
                .item-details { flex: 1; }
                .item-total { text-align: right; min-width: 80px; }
                .totals { margin: 10px 0; }
                .total-line { display: flex; justify-content: space-between; margin: 3px 0; font-size: 12px; }
                .total-line.grand { font-weight: bold; border-top: 1px solid #333; padding-top: 5px; }
                .payment { margin: 15px 0; font-size: 12px; }
                .footer { text-align: center; margin-top: 20px; font-size: 10px; }
                .dashed { border-top: 1px dashed #333; margin: 10px 0; }
            </style>
        </head>
        <body>
            <div class="receipt">
                #{render_header(data[:company])}
                #{render_order_info(data[:order], data[:metadata])}
                #{render_items(data[:items])}
                #{render_totals(data[:totals])}
                #{render_payment(data[:payment])}
                #{render_footer(data[:footer], data[:metadata])}
            </div>
        </body>
        </html>
      HTML
    end

    # Generate thermal printer receipt (58mm width)
    def generate_thermal_receipt(data)
      width = 32 # characters for 58mm thermal printer

      receipt = []
      receipt << center_text(data[:company][:name], width)
      receipt << center_text(data[:company][:address], width) if data[:company][:address]
      receipt << center_text(data[:company][:phone], width) if data[:company][:phone]
      receipt << "=" * width

      receipt << "No: #{data[:order][:order_no]}"
      receipt << "Tanggal: #{data[:order][:date]}"
      receipt << "Waktu: #{data[:order][:time]}"
      receipt << "Kasir: #{data[:metadata][:cashier]}"
      receipt << "-" * width

      data[:items].each do |item|
        receipt << "#{item[:name]}"
        receipt << sprintf("%d x %s = %s",
          item[:quantity],
          format_currency_short(item[:price]),
          format_currency_short(item[:line_total])
        )
      end

      receipt << "-" * width
      receipt << sprintf("%-20s %s", "Subtotal:", format_currency_short(data[:totals][:sub_total]))

      if data[:totals][:discount_amount] > 0
        receipt << sprintf("%-20s %s", "Diskon:", format_currency_short(data[:totals][:discount_amount]))
      end

      if data[:totals][:tax_amount] > 0
        receipt << sprintf("%-20s %s", "PPN 11%:", format_currency_short(data[:totals][:tax_amount]))
      end

      receipt << "=" * width
      receipt << sprintf("%-20s %s", "TOTAL:", format_currency_short(data[:totals][:grand_total]))
      receipt << sprintf("%-20s %s", "Bayar:", format_currency_short(data[:payment][:paid_amount]))
      receipt << sprintf("%-20s %s", "Kembali:", format_currency_short(data[:payment][:change_amount]))
      receipt << "=" * width

      receipt << center_text("Terima kasih atas kunjungan Anda", width)
      receipt << center_text(data[:footer][:message], width) if data[:footer][:message]

      receipt.join("\n")
    end

    # Generate PDF-ready receipt
    def generate_pdf_receipt(data)
      # This would integrate with a PDF library like Prawn
      # For now, return enhanced HTML suitable for PDF conversion
      standard_html = generate_standard_receipt(data)

      # Add PDF-specific styling
      standard_html.gsub(
        "<style>",
        '<style>
          @media print {
            body { margin: 0; }
            .receipt { border: none; box-shadow: none; }
          }
          @page { size: A5; margin: 15mm; }'
      )
    end

    # Generate email-friendly receipt
    def generate_email_receipt(data)
      generate_standard_receipt(data).gsub(
        "font-family: 'Courier New', monospace;",
        "font-family: Arial, sans-serif;"
      )
    end

    def render_header(company)
      <<~HTML
        <div class="header">
            <div class="company-name">#{company[:name]}</div>
            #{company[:address] ? "<div class=\"company-info\">#{company[:address]}</div>" : ""}
            #{company[:phone] ? "<div class=\"company-info\">Telepon: #{company[:phone]}</div>" : ""}
            #{company[:email] ? "<div class=\"company-info\">Email: #{company[:email]}</div>" : ""}
        </div>
      HTML
    end

    def render_order_info(order, metadata)
      <<~HTML
        <div class="order-info">
            <div><strong>No. Transaksi:</strong> #{order[:order_no]}</div>
            <div><strong>Tanggal:</strong> #{order[:date]}</div>
            <div><strong>Waktu:</strong> #{order[:time]}</div>
            <div><strong>Kasir:</strong> #{metadata[:cashier]}</div>
        </div>
      HTML
    end

    def render_items(items)
      items_html = items.map do |item|
        <<~HTML
          <div class="item">
              <div class="item-details">
                  <div><strong>#{item[:name]}</strong></div>
                  <div>#{item[:quantity]} x #{item[:formatted_price]}</div>
              </div>
              <div class="item-total">#{item[:formatted_line_total]}</div>
          </div>
        HTML
      end.join

      "<div class=\"items\">#{items_html}</div>"
    end

    def render_totals(totals)
      html = '<div class="totals">'
      html += "<div class=\"total-line\"><span>Subtotal:</span><span>#{totals[:formatted_sub_total]}</span></div>"

      if totals[:discount_amount] > 0
        html += "<div class=\"total-line\"><span>Diskon:</span><span>-#{totals[:formatted_discount]}</span></div>"
      end

      if totals[:tax_amount] > 0
        html += "<div class=\"total-line\"><span>PPN 11%:</span><span>#{totals[:formatted_tax]}</span></div>"
      end

      html += "<div class=\"total-line grand\"><span>TOTAL:</span><span>#{totals[:formatted_grand_total]}</span></div>"
      html += "</div>"
    end

    def render_payment(payment)
      html = '<div class="payment">'
      html += "<div class=\"total-line\"><span>Metode Bayar:</span><span>#{payment[:payment_method]}</span></div>"
      html += "<div class=\"total-line\"><span>Jumlah Bayar:</span><span>#{payment[:formatted_amounts][:paid_amount]}</span></div>"

      if payment[:change_amount] > 0
        html += "<div class=\"total-line\"><span>Kembalian:</span><span>#{payment[:formatted_amounts][:change_amount]}</span></div>"

        if payment[:change_breakdown].present?
          html += '<div style="margin-top: 10px; font-size: 10px;">'
          html += "<div><strong>Rincian Kembalian:</strong></div>"
          payment[:change_breakdown].each do |breakdown|
            html += "<div>#{breakdown[:count]}x #{breakdown[:formatted_denomination]} = #{breakdown[:formatted_total]}</div>"
          end
          html += "</div>"
        end
      end

      html += "</div>"
    end

    def render_footer(footer, metadata)
      <<~HTML
        <div class="dashed"></div>
        <div class="footer">
            <div>#{footer[:message] || 'Terima kasih atas kunjungan Anda'}</div>
            #{footer[:website] ? "<div>#{footer[:website]}</div>" : ""}
            <div style="margin-top: 10px;">
                Receipt: R#{metadata[:printed_at].strftime('%Y%m%d%H%M%S')}
            </div>
            <div>Dicetak: #{metadata[:printed_at].strftime('%d/%m/%Y %H:%M:%S')}</div>
        </div>
      HTML
    end

    def company_info(company)
      {
        name: company.name,
        address: company.address,
        phone: company.phone,
        email: company.email,
        website: company.website
      }
    end

    def order_info(sales_order)
      {
        order_no: sales_order.order_no,
        date: sales_order.created_at.strftime("%d/%m/%Y"),
        time: sales_order.created_at.strftime("%H:%M:%S"),
        status: sales_order.status.humanize
      }
    end

    def items_info(sales_order_items)
      sales_order_items.map do |item|
        {
          name: item.item.name,
          quantity: item.quantity,
          price: item.price,
          line_total: item.line_total_with_tax,
          formatted_price: PaymentService.format_rupiah(item.price),
          formatted_line_total: PaymentService.format_rupiah(item.line_total_with_tax)
        }
      end
    end

    def totals_info(sales_order)
      {
        sub_total: sales_order.sub_total,
        discount_amount: sales_order.discount_amount || 0,
        tax_amount: sales_order.tax_amount || 0,
        grand_total: sales_order.grand_total,
        formatted_sub_total: PaymentService.format_rupiah(sales_order.sub_total),
        formatted_discount: PaymentService.format_rupiah(sales_order.discount_amount || 0),
        formatted_tax: PaymentService.format_rupiah(sales_order.tax_amount || 0),
        formatted_grand_total: PaymentService.format_rupiah(sales_order.grand_total)
      }
    end

    def footer_info(company, options)
      {
        message: options[:footer_message] || company.receipt_footer_message,
        website: company.website,
        return_policy: company.return_policy
      }
    end

    def center_text(text, width)
      return "" if text.blank?
      padding = [ (width - text.length) / 2, 0 ].max
      (" " * padding) + text
    end

    def format_currency_short(amount)
      # Shortened format for thermal receipts
      amount_str = amount.to_i.to_s
      if amount_str.length > 6
        "#{amount_str[0..-7]}#{amount_str[-6..-1].to_i > 0 ? '.' + amount_str[-6..-4] : ''}jt"
      elsif amount_str.length > 3
        "#{amount_str[0..-4]}#{amount_str[-3..-1].to_i > 0 ? '.' + amount_str[-3..-1] : ''}rb"
      else
        amount_str
      end
    end
  end
end
