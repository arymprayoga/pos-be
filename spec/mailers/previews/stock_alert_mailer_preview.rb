# Preview all emails at http://localhost:3000/rails/mailers/stock_alert_mailer_mailer
class StockAlertMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/stock_alert_mailer_mailer/low_stock_alert
  def low_stock_alert
    StockAlertMailer.low_stock_alert
  end

  # Preview this email at http://localhost:3000/rails/mailers/stock_alert_mailer_mailer/out_of_stock_alert
  def out_of_stock_alert
    StockAlertMailer.out_of_stock_alert
  end
end
