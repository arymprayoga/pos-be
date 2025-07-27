require 'rails_helper'

RSpec.describe Inventory, type: :model do
  let(:company) { create(:company) }
  let(:category) { create(:category, company: company) }
  let(:item) { create(:item, company: company, category: category) }
  let(:inventory) { build(:inventory, company: company, item: item) }

  describe 'associations' do
    it { should belong_to(:company) }
    it { should belong_to(:item) }
    it { should have_many(:inventory_ledgers).through(:item) }
  end

  describe 'validations' do
    subject { inventory }

    it { should validate_presence_of(:stock) }
    it { should validate_numericality_of(:stock).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:minimum_stock) }
    it { should validate_numericality_of(:minimum_stock).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:reserved_stock) }
    it { should validate_numericality_of(:reserved_stock).is_greater_than_or_equal_to(0) }
  end

  describe 'scopes' do
    before do
      @normal_inventory = create(:inventory, company: company, item: item, stock: 100, minimum_stock: 10)
      @low_stock_inventory = create(:inventory, company: company, item: create(:item, company: company, category: category), stock: 5, minimum_stock: 10)
      @deleted_inventory = create(:inventory, company: company, item: create(:item, company: company, category: category))
      @deleted_inventory.soft_delete!
    end

    describe '.not_deleted' do
      it 'returns only non-deleted inventories' do
        expect(Inventory.not_deleted).to include(@normal_inventory, @low_stock_inventory)
        expect(Inventory.not_deleted).not_to include(@deleted_inventory)
      end
    end

    describe '.low_stock' do
      it 'returns inventories where stock is less than or equal to minimum stock' do
        expect(Inventory.low_stock).to include(@low_stock_inventory)
        expect(Inventory.low_stock).not_to include(@normal_inventory)
      end
    end
  end

  describe 'tenant behavior' do
    it 'acts as tenant' do
      expect(Inventory.new).to respond_to(:company_id)
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at timestamp' do
      inventory.save!
      expect { inventory.soft_delete! }.to change { inventory.deleted_at }.from(nil)
    end

    it 'does not actually destroy the record' do
      inventory.save!
      expect { inventory.soft_delete! }.not_to change { Inventory.count }
    end
  end

  describe '#deleted?' do
    it 'returns false when deleted_at is nil' do
      expect(inventory.deleted?).to be false
    end

    it 'returns true when deleted_at is present' do
      inventory.deleted_at = Time.current
      expect(inventory.deleted?).to be true
    end
  end

  describe '#available_stock' do
    it 'returns stock minus reserved stock' do
      inventory.stock = 100
      inventory.reserved_stock = 20
      expect(inventory.available_stock).to eq(80)
    end

    it 'handles zero reserved stock' do
      inventory.stock = 50
      inventory.reserved_stock = 0
      expect(inventory.available_stock).to eq(50)
    end
  end

  describe '#low_stock?' do
    it 'returns true when stock is less than minimum stock' do
      inventory.stock = 5
      inventory.minimum_stock = 10
      expect(inventory.low_stock?).to be true
    end

    it 'returns true when stock equals minimum stock' do
      inventory.stock = 10
      inventory.minimum_stock = 10
      expect(inventory.low_stock?).to be true
    end

    it 'returns false when stock is greater than minimum stock' do
      inventory.stock = 15
      inventory.minimum_stock = 10
      expect(inventory.low_stock?).to be false
    end
  end
end
