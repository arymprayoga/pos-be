require 'rails_helper'

RSpec.describe Item, type: :model do
  let(:company) { create(:company) }
  let(:category) { create(:category, company: company) }
  let(:item) { build(:item, company: company, category: category) }

  describe 'associations' do
    it { should belong_to(:company) }
    it { should belong_to(:category) }
    it { should have_one(:inventory).dependent(:destroy) }
    it { should have_many(:sales_order_items).dependent(:destroy) }
    it { should have_many(:inventory_ledgers).dependent(:destroy) }
  end

  describe 'validations' do
    subject { item }

    it { should validate_presence_of(:sku) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:price) }
    it { should validate_numericality_of(:price).is_greater_than(0) }

    context 'uniqueness validation' do
      it 'validates uniqueness of sku scoped to company' do
        create(:item, sku: 'TEST-SKU', company: company, category: category)
        duplicate = build(:item, sku: 'TEST-SKU', company: company, category: category)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:sku]).to include('has already been taken')
      end

      it 'allows same sku in different companies' do
        create(:item, sku: 'TEST-SKU', company: company, category: category)
        other_company = create(:company)
        other_category = create(:category, company: other_company)
        duplicate = build(:item, sku: 'TEST-SKU', company: other_company, category: other_category)
        expect(duplicate).to be_valid
      end

      it 'allows same sku if original is soft deleted' do
        original = create(:item, sku: 'UNIQUE-SKU', company: company, category: category)
        original.soft_delete!
        duplicate = build(:item, sku: 'UNIQUE-SKU', company: company, category: category)
        expect(duplicate).to be_valid
      end
    end
  end

  describe 'scopes' do
    before do
      @active_item = create(:item, company: company, category: category, active: true)
      @inactive_item = create(:item, company: company, category: category, active: false)
      @deleted_item = create(:item, company: company, category: category)
      @deleted_item.soft_delete!
    end

    describe '.active' do
      it 'returns only active items' do
        expect(Item.active).to include(@active_item)
        expect(Item.active).not_to include(@inactive_item)
      end
    end

    describe '.not_deleted' do
      it 'returns only non-deleted items' do
        expect(Item.not_deleted).to include(@active_item, @inactive_item)
        expect(Item.not_deleted).not_to include(@deleted_item)
      end
    end

    describe '.ordered' do
      it 'orders by sort_order and name' do
        test_company = create(:company)
        test_category = create(:category, company: test_company)
        item1 = create(:item, company: test_company, category: test_category, sort_order: 2, name: 'B')
        item2 = create(:item, company: test_company, category: test_category, sort_order: 1, name: 'A')
        item3 = create(:item, company: test_company, category: test_category, sort_order: 1, name: 'C')

        expect(Item.where(company: test_company).ordered).to eq([ item2, item3, item1 ])
      end
    end
  end

  describe 'tenant behavior' do
    it 'acts as tenant' do
      expect(Item.new).to respond_to(:company_id)
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at timestamp' do
      item.save!
      expect { item.soft_delete! }.to change { item.deleted_at }.from(nil)
    end

    it 'does not actually destroy the record' do
      item.save!
      expect { item.soft_delete! }.not_to change { Item.count }
    end
  end

  describe '#deleted?' do
    it 'returns false when deleted_at is nil' do
      expect(item.deleted?).to be false
    end

    it 'returns true when deleted_at is present' do
      item.deleted_at = Time.current
      expect(item.deleted?).to be true
    end
  end

  describe '#current_stock' do
    context 'when item has inventory' do
      it 'returns inventory stock' do
        item.save!
        create(:inventory, item: item, stock: 50)
        expect(item.current_stock).to eq(50)
      end
    end

    context 'when item has no inventory' do
      it 'returns 0' do
        item.save!
        expect(item.current_stock).to eq(0)
      end
    end
  end

  describe '#low_stock?' do
    before { item.save! }

    context 'when track_inventory is false' do
      it 'returns false' do
        item.update!(track_inventory: false)
        expect(item.low_stock?).to be false
      end
    end

    context 'when track_inventory is true' do
      before { item.update!(track_inventory: true) }

      context 'when current stock is above minimum' do
        it 'returns false' do
          create(:inventory, item: item, stock: 10, minimum_stock: 5)
          expect(item.low_stock?).to be false
        end
      end

      context 'when current stock equals minimum' do
        it 'returns true' do
          create(:inventory, item: item, stock: 5, minimum_stock: 5)
          expect(item.low_stock?).to be true
        end
      end

      context 'when current stock is below minimum' do
        it 'returns true' do
          create(:inventory, item: item, stock: 3, minimum_stock: 5)
          expect(item.low_stock?).to be true
        end
      end

      context 'when minimum stock is 0' do
        it 'returns true when stock is 0 or less' do
          create(:inventory, item: item, stock: 0, minimum_stock: 0)
          expect(item.low_stock?).to be true
        end
      end
    end
  end

  describe '#in_stock?' do
    before { item.save! }

    context 'when track_inventory is false' do
      it 'returns true' do
        item.update!(track_inventory: false)
        expect(item.in_stock?).to be true
      end
    end

    context 'when track_inventory is true' do
      before { item.update!(track_inventory: true) }

      context 'when current stock is greater than 0' do
        it 'returns true' do
          create(:inventory, item: item, stock: 5)
          expect(item.in_stock?).to be true
        end
      end

      context 'when current stock is 0' do
        it 'returns false' do
          create(:inventory, item: item, stock: 0)
          expect(item.in_stock?).to be false
        end
      end

      context 'when no inventory exists' do
        it 'returns false' do
          expect(item.in_stock?).to be false
        end
      end
    end
  end
end
