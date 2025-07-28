require "rails_helper"

RSpec.describe StockAlertMailer, type: :mailer do
  describe "low_stock_alert" do
    let(:mail) { StockAlertMailer.low_stock_alert }

    it "renders the headers" do
      expect(mail.subject).to eq("Low stock alert")
      expect(mail.to).to eq([ "to@example.org" ])
      expect(mail.from).to eq([ "from@example.com" ])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hi")
    end
  end

  describe "out_of_stock_alert" do
    let(:mail) { StockAlertMailer.out_of_stock_alert }

    it "renders the headers" do
      expect(mail.subject).to eq("Out of stock alert")
      expect(mail.to).to eq([ "to@example.org" ])
      expect(mail.from).to eq([ "from@example.com" ])
    end

    it "renders the body" do
      expect(mail.body.encoded).to match("Hi")
    end
  end
end
