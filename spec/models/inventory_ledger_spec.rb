require 'rails_helper'

RSpec.describe InventoryLedger, type: :model do
  let(:company) { create(:company) }
  let(:category) { create(:category, company: company) }
  let(:item) { create(:item, company: company, category: category) }
  let(:inventory_ledger) { build(:inventory_ledger, company: company, item: item) }

  describe 'associations' do
    it { should belong_to(:company) }
    it { should belong_to(:item) }
    it { should belong_to(:sales_order_item).optional }
  end

  describe 'validations' do
    subject { inventory_ledger }

    it { should validate_presence_of(:movement_type) }
    it { should validate_presence_of(:quantity) }
    it { should validate_numericality_of(:quantity).is_other_than(0) }
  end

  describe 'enums' do
    it { should define_enum_for(:movement_type).with_values(stock_in: 0, stock_out: 1, adjustment: 2) }
  end

  describe 'scopes' do
    before do
      @recent_ledger = create(:inventory_ledger, company: company, item: item, created_at: 1.hour.ago)
      @old_ledger = create(:inventory_ledger, company: company, item: item, created_at: 1.week.ago)
      @deleted_ledger = create(:inventory_ledger, company: company, item: item)
      @deleted_ledger.soft_delete!
    end

    describe '.not_deleted' do
      it 'returns only non-deleted ledgers' do
        expect(InventoryLedger.not_deleted).to include(@recent_ledger, @old_ledger)
        expect(InventoryLedger.not_deleted).not_to include(@deleted_ledger)
      end
    end

    describe '.recent' do
      it 'orders by created_at desc' do
        expect(InventoryLedger.where(company: company).not_deleted.recent.first).to eq(@recent_ledger)
      end
    end
  end

  describe 'tenant behavior' do
    it 'acts as tenant' do
      expect(InventoryLedger.new).to respond_to(:company_id)
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at timestamp' do
      inventory_ledger.save!
      expect { inventory_ledger.soft_delete! }.to change { inventory_ledger.deleted_at }.from(nil)
    end

    it 'does not actually destroy the record' do
      inventory_ledger.save!
      expect { inventory_ledger.soft_delete! }.not_to change { InventoryLedger.count }
    end
  end

  describe '#deleted?' do
    it 'returns false when deleted_at is nil' do
      expect(inventory_ledger.deleted?).to be false
    end

    it 'returns true when deleted_at is present' do
      inventory_ledger.deleted_at = Time.current
      expect(inventory_ledger.deleted?).to be true
    end
  end

  describe '#quantity_with_sign' do
    context 'for stock_in movement' do
      it 'returns positive quantity' do
        inventory_ledger.movement_type = 'stock_in'
        inventory_ledger.quantity = 10
        expect(inventory_ledger.quantity_with_sign).to eq(10)
      end

      it 'returns positive quantity even if stored as negative' do
        inventory_ledger.movement_type = 'stock_in'
        inventory_ledger.quantity = -10
        expect(inventory_ledger.quantity_with_sign).to eq(10)
      end
    end

    context 'for stock_out movement' do
      it 'returns negative quantity' do
        inventory_ledger.movement_type = 'stock_out'
        inventory_ledger.quantity = 10
        expect(inventory_ledger.quantity_with_sign).to eq(-10)
      end

      it 'returns negative quantity even if stored as negative' do
        inventory_ledger.movement_type = 'stock_out'
        inventory_ledger.quantity = -10
        expect(inventory_ledger.quantity_with_sign).to eq(-10)
      end
    end

    context 'for adjustment movement' do
      it 'returns positive quantity for positive adjustments' do
        inventory_ledger.movement_type = 'adjustment'
        inventory_ledger.quantity = 5
        expect(inventory_ledger.quantity_with_sign).to eq(5)
      end

      it 'returns positive quantity for negative adjustments' do
        inventory_ledger.movement_type = 'adjustment'
        inventory_ledger.quantity = -5
        expect(inventory_ledger.quantity_with_sign).to eq(5)
      end
    end
  end
end
