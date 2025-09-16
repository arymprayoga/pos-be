require 'rails_helper'

RSpec.describe PaymentService, type: :service do
  describe '.calculate_change' do
    context 'with sufficient payment' do
      it 'calculates change correctly' do
        result = described_class.calculate_change(
          total_amount: 50000,
          paid_amount: 60000
        )

        expect(result[:success]).to be true
        expect(result[:change_amount]).to eq(BigDecimal('10000'))
        expect(result[:formatted_change]).to eq('Rp 10.000')
        expect(result[:change_breakdown]).to be_an(Array)
      end

      it 'provides denomination breakdown' do
        result = described_class.calculate_change(
          total_amount: 15000,
          paid_amount: 25000
        )

        breakdown = result[:change_breakdown]
        expect(breakdown).to be_an(Array)
        expect(breakdown.first[:denomination]).to eq(10000)
        expect(breakdown.first[:count]).to eq(1)
      end
    end

    context 'with insufficient payment' do
      it 'returns error for insufficient payment' do
        result = described_class.calculate_change(
          total_amount: 50000,
          paid_amount: 40000
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Insufficient payment')
      end
    end

    context 'with exact payment' do
      it 'calculates zero change' do
        result = described_class.calculate_change(
          total_amount: 50000,
          paid_amount: 50000
        )

        expect(result[:success]).to be true
        expect(result[:change_amount]).to eq(BigDecimal('0'))
        expect(result[:change_breakdown]).to eq([])
      end
    end
  end

  describe '.validate_payment' do
    let(:payment_method) { create(:payment_method, name: 'Cash') }

    context 'with cash payment' do
      it 'validates sufficient cash payment' do
        result = described_class.validate_payment(
          payment_method: payment_method,
          amount_due: 50000,
          amount_paid: 60000
        )

        expect(result[:success]).to be true
        expect(result[:change_amount]).to eq(BigDecimal('10000'))
      end

      it 'rejects insufficient cash payment' do
        result = described_class.validate_payment(
          payment_method: payment_method,
          amount_due: 50000,
          amount_paid: 40000
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('Insufficient')
        expect(result[:shortfall]).to eq(BigDecimal('10000'))
      end
    end

    context 'with card payment' do
      let(:card_payment_method) { create(:payment_method, name: 'Card') }

      it 'requires exact amount for card payment' do
        result = described_class.validate_payment(
          payment_method: card_payment_method,
          amount_due: 50000,
          amount_paid: 60000
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('exact amount')
      end

      it 'accepts exact card payment' do
        result = described_class.validate_payment(
          payment_method: card_payment_method,
          amount_due: 50000,
          amount_paid: 50000
        )

        expect(result[:success]).to be true
        expect(result[:change_amount]).to eq(BigDecimal('0'))
      end
    end
  end

  describe '.process_split_payment' do
    let(:cash_method) { create(:payment_method, name: 'Cash') }
    let(:card_method) { create(:payment_method, name: 'Card') }

    context 'with valid split payment' do
      it 'processes multiple payment methods' do
        payments = [
          { payment_method_id: cash_method.id, amount: 30000 },
          { payment_method_id: card_method.id, amount: 20000 }
        ]

        result = described_class.process_split_payment(
          total_amount: 50000,
          payments: payments
        )

        expect(result[:success]).to be true
        expect(result[:total_paid]).to eq(BigDecimal('50000'))
        expect(result[:change_amount]).to eq(BigDecimal('0'))
        expect(result[:payments].size).to eq(2)
      end

      it 'calculates change from overpayment' do
        payments = [
          { payment_method_id: cash_method.id, amount: 35000 },
          { payment_method_id: card_method.id, amount: 20000 }
        ]

        result = described_class.process_split_payment(
          total_amount: 50000,
          payments: payments
        )

        expect(result[:success]).to be true
        expect(result[:change_amount]).to eq(BigDecimal('5000'))
      end
    end

    context 'with insufficient split payment' do
      it 'returns error for insufficient total' do
        payments = [
          { payment_method_id: cash_method.id, amount: 20000 },
          { payment_method_id: card_method.id, amount: 15000 }
        ]

        result = described_class.process_split_payment(
          total_amount: 50000,
          payments: payments
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('insufficient')
        expect(result[:shortfall]).to eq(BigDecimal('15000'))
      end
    end
  end

  describe '.cash_drawer_summary' do
    let(:cash_method) { create(:payment_method, name: 'Cash') }
    let(:card_method) { create(:payment_method, name: 'Card') }

    before do
      # Create some sample sales orders
      create(:sales_order, payment_method: cash_method, grand_total: 50000, change_amount: 5000)
      create(:sales_order, payment_method: cash_method, grand_total: 30000, change_amount: 0)
      create(:sales_order, payment_method: card_method, grand_total: 25000, change_amount: 0)
    end

    it 'calculates cash drawer summary correctly' do
      cash_sales = SalesOrder.joins(:payment_method).where(payment_methods: { name: 'Cash' })

      result = described_class.cash_drawer_summary(
        sales_orders: cash_sales,
        starting_cash: 100000
      )

      expect(result[:total_cash_sales]).to eq(80000)
      expect(result[:total_change_given]).to eq(5000)
      expect(result[:net_cash_received]).to eq(75000)
      expect(result[:expected_cash]).to eq(175000)
      expect(result[:transaction_count]).to eq(2)
    end
  end

  describe '.format_rupiah' do
    it 'formats small amounts correctly' do
      formatted = described_class.format_rupiah(BigDecimal('1000'))
      expect(formatted).to eq('Rp 1.000')
    end

    it 'formats large amounts with proper separators' do
      formatted = described_class.format_rupiah(BigDecimal('1500000'))
      expect(formatted).to eq('Rp 1.500.000')
    end

    it 'handles zero amount' do
      formatted = described_class.format_rupiah(BigDecimal('0'))
      expect(formatted).to eq('Rp 0')
    end

    it 'formats very large amounts' do
      formatted = described_class.format_rupiah(BigDecimal('123456789'))
      expect(formatted).to eq('Rp 123.456.789')
    end
  end

  describe '.round_to_denomination' do
    it 'rounds to nearest valid denomination' do
      rounded = described_class.round_to_denomination(BigDecimal('1234.56'))
      expect(rounded).to eq(BigDecimal('1235'))
    end

    it 'rounds down when needed' do
      rounded = described_class.round_to_denomination(BigDecimal('1234.49'))
      expect(rounded).to eq(BigDecimal('1234'))
    end

    it 'handles already rounded amounts' do
      rounded = described_class.round_to_denomination(BigDecimal('1000'))
      expect(rounded).to eq(BigDecimal('1000'))
    end
  end
end
