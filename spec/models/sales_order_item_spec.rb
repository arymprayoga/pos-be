require 'rails_helper'

RSpec.describe SalesOrderItem, type: :model do
  let(:company) { create(:company) }
  let(:category) { create(:category, company: company) }
  let(:item) { create(:item, company: company, category: category) }
  let(:payment_method) { create(:payment_method, company: company) }
  let(:sales_order) { create(:sales_order, company: company, payment_method: payment_method) }
  let(:sales_order_item) { build(:sales_order_item, sales_order: sales_order, item: item) }

  describe 'associations' do
    it { should belong_to(:sales_order) }
    it { should belong_to(:item) }
    it { should have_many(:inventory_ledgers).dependent(:destroy) }
  end

  describe 'validations' do
    subject { sales_order_item }

    it { should validate_presence_of(:price) }
    it { should validate_numericality_of(:price).is_greater_than(0) }
    it { should validate_presence_of(:quantity) }
    it { should validate_numericality_of(:quantity).is_greater_than(0) }
  end

  describe 'scopes' do
    before do
      @active_item = create(:sales_order_item, sales_order: sales_order, item: item)
      @deleted_item = create(:sales_order_item, sales_order: sales_order, item: item)
      @deleted_item.soft_delete!
    end

    describe '.not_deleted' do
      it 'returns only non-deleted order items' do
        expect(SalesOrderItem.not_deleted).to include(@active_item)
        expect(SalesOrderItem.not_deleted).not_to include(@deleted_item)
      end
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at timestamp' do
      sales_order_item.save!
      expect { sales_order_item.soft_delete! }.to change { sales_order_item.deleted_at }.from(nil)
    end

    it 'does not actually destroy the record' do
      sales_order_item.save!
      expect { sales_order_item.soft_delete! }.not_to change { SalesOrderItem.count }
    end
  end

  describe '#deleted?' do
    it 'returns false when deleted_at is nil' do
      expect(sales_order_item.deleted?).to be false
    end

    it 'returns true when deleted_at is present' do
      sales_order_item.deleted_at = Time.current
      expect(sales_order_item.deleted?).to be true
    end
  end

  describe '#line_total' do
    it 'returns price multiplied by quantity' do
      sales_order_item.price = 10.50
      sales_order_item.quantity = 3
      expect(sales_order_item.line_total).to eq(31.50)
    end
  end

  describe '#line_total_with_tax' do
    it 'returns line total plus tax amount' do
      sales_order_item.price = 10.00
      sales_order_item.quantity = 2
      sales_order_item.tax_amount = 2.00
      expect(sales_order_item.line_total_with_tax).to eq(22.00)
    end

    it 'handles zero tax amount' do
      sales_order_item.price = 15.00
      sales_order_item.quantity = 1
      sales_order_item.tax_amount = 0
      expect(sales_order_item.line_total_with_tax).to eq(15.00)
    end
  end

  describe '#company' do
    it 'returns the company through sales_order' do
      expect(sales_order_item.company).to eq(company)
    end
  end

  describe '#revert_inventory!' do
    let(:inventory) { create(:inventory, item: item, company: company, stock: 50) }

    before do
      sales_order_item.save!
      inventory
    end

    context 'when item tracks inventory' do
      before { item.update!(track_inventory: true) }

      it 'creates an inventory ledger entry' do
        expect { sales_order_item.revert_inventory! }.to change { InventoryLedger.count }.by(1)
      end

      it 'creates ledger with correct attributes' do
        sales_order_item.revert_inventory!
        ledger = InventoryLedger.last

        expect(ledger.company).to eq(company)
        expect(ledger.item).to eq(item)
        expect(ledger.movement_type).to eq('stock_in')
        expect(ledger.quantity).to eq(sales_order_item.quantity)
        expect(ledger.sales_order_item).to eq(sales_order_item)
        expect(ledger.remarks).to include("Reverted from voided order #{sales_order.order_no}")
      end

      it 'increments item inventory stock' do
        original_stock = inventory.stock
        quantity = sales_order_item.quantity

        expect { sales_order_item.revert_inventory! }.to change { inventory.reload.stock }.by(quantity)
      end
    end

    context 'when item does not track inventory' do
      before { item.update!(track_inventory: false) }

      it 'does not create inventory ledger entry' do
        expect { sales_order_item.revert_inventory! }.not_to change { InventoryLedger.count }
      end

      it 'does not change inventory stock' do
        original_stock = inventory.stock
        sales_order_item.revert_inventory!
        expect(inventory.reload.stock).to eq(original_stock)
      end
    end
  end
end
