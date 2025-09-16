require 'rails_helper'

RSpec.describe TransactionService, type: :service do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:payment_method) { create(:payment_method, company: company, name: 'Cash') }
  let(:item) { create(:item, company: company, price: 10000) }
  let(:inventory) { create(:inventory, item: item, stock: 100) }

  before do
    inventory # Create inventory
  end

  describe '.create_transaction' do
    let(:transaction_params) {
      {
        company: company,
        user: user,
        items: [
          { item_id: item.id, quantity: 2, price: 10000 }
        ],
        payment_method_id: payment_method.id,
        paid_amount: 25000,
        options: { notes: 'Test transaction' }
      }
    }

    context 'with valid parameters' do
      it 'creates a successful transaction' do
        result = described_class.create_transaction(**transaction_params)

        expect(result[:success]).to be true
        expect(result[:sales_order]).to be_persisted
        expect(result[:sales_order].status).to eq('completed')
        expect(result[:sales_order].grand_total).to eq(20000)
        expect(result[:change_amount]).to eq(5000)
      end

      it 'updates inventory correctly' do
        expect {
          described_class.create_transaction(**transaction_params)
        }.to change { inventory.reload.stock }.by(-2)
      end

      it 'creates inventory ledger entries' do
        expect {
          described_class.create_transaction(**transaction_params)
        }.to change(InventoryLedger, :count).by(1)
      end

      it 'generates proper order number' do
        result = described_class.create_transaction(**transaction_params)

        expect(result[:sales_order].order_no).to match(/^\d{8}-\d{4}$/)
      end
    end

    context 'with insufficient payment' do
      before { transaction_params[:paid_amount] = 15000 }

      it 'returns error for insufficient payment' do
        result = described_class.create_transaction(**transaction_params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Insufficient payment')
      end
    end

    context 'with insufficient stock' do
      before { inventory.update!(stock: 1) }

      it 'returns error for insufficient stock' do
        result = described_class.create_transaction(**transaction_params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Insufficient stock')
      end
    end

    context 'with invalid payment method' do
      before { transaction_params[:payment_method_id] = 999 }

      it 'returns error for invalid payment method' do
        result = described_class.create_transaction(**transaction_params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Invalid payment method')
      end
    end
  end

  describe '.void_transaction' do
    let(:sales_order) { create(:sales_order, company: company, status: 'completed', created_at: 1.hour.ago) }
    let(:sales_order_item) do
      create(:sales_order_item, sales_order: sales_order, item: item, quantity: 2)
    end

    before do
      sales_order_item
      inventory.update!(stock: 98) # Simulate stock reduction
    end

    context 'with voidable transaction' do
      it 'successfully voids the transaction' do
        result = described_class.void_transaction(
          sales_order: sales_order,
          user: user,
          reason: 'Customer request'
        )

        expect(result[:success]).to be true
        expect(sales_order.reload.status).to eq('voided')
        expect(sales_order.void_reason).to eq('Customer request')
      end

      it 'reverts inventory' do
        expect {
          described_class.void_transaction(
            sales_order: sales_order,
            user: user,
            reason: 'Customer request'
          )
        }.to change { inventory.reload.stock }.by(2)
      end
    end

    context 'with non-voidable transaction' do
      before { sales_order.update!(created_at: 2.days.ago) }

      it 'returns error for old transaction' do
        result = described_class.void_transaction(
          sales_order: sales_order,
          user: user,
          reason: 'Too old'
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('cannot be voided')
      end
    end
  end

  describe '.transaction_summary' do
    let!(:completed_order1) do
      create(:sales_order,
        company: company,
        status: 'completed',
        grand_total: 50000,
        created_at: 1.day.ago
      )
    end
    let!(:completed_order2) do
      create(:sales_order,
        company: company,
        status: 'completed',
        grand_total: 30000,
        created_at: 1.day.ago
      )
    end
    let!(:voided_order) do
      create(:sales_order,
        company: company,
        status: 'voided',
        grand_total: 20000,
        created_at: 1.day.ago
      )
    end

    it 'returns correct transaction summary' do
      date_range = 2.days.ago..Time.current

      summary = described_class.transaction_summary(
        company: company,
        date_range: date_range
      )

      expect(summary[:total_transactions]).to eq(2)
      expect(summary[:total_revenue]).to eq(80000)
      expect(summary[:average_transaction]).to eq(40000.0)
      expect(summary[:voided_transactions]).to eq(1)
      expect(summary[:voided_amount]).to eq(20000)
      expect(summary[:currency]).to eq('IDR')
    end
  end
end
