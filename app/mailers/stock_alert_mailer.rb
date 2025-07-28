class StockAlertMailer < ApplicationMailer
  default from: "noreply@pos-system.com"

  def low_stock_alert(stock_alert, recipients)
    @stock_alert = stock_alert
    @item = stock_alert.item
    @company = stock_alert.company
    @current_stock = @item.current_stock
    @threshold = stock_alert.threshold_value

    mail(
      to: recipients,
      subject: "Low Stock Alert: #{@item.name} - #{@company.name}"
    )
  end

  def out_of_stock_alert(stock_alert, recipients)
    @stock_alert = stock_alert
    @item = stock_alert.item
    @company = stock_alert.company

    mail(
      to: recipients,
      subject: "Out of Stock Alert: #{@item.name} - #{@company.name}"
    )
  end

  def overstock_alert(stock_alert, recipients)
    @stock_alert = stock_alert
    @item = stock_alert.item
    @company = stock_alert.company
    @current_stock = @item.current_stock
    @threshold = stock_alert.threshold_value

    mail(
      to: recipients,
      subject: "Overstock Alert: #{@item.name} - #{@company.name}"
    )
  end
end
