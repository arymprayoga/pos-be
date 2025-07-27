require 'rails_helper'

RSpec.describe Category, type: :model do
  let(:company) { create(:company) }
  let(:category) { build(:category, company: company) }

  describe 'associations' do
    it { should belong_to(:company) }
    it { should have_many(:items).dependent(:destroy) }
  end

  describe 'validations' do
    subject { category }

    it { should validate_presence_of(:name) }

    context 'uniqueness validation' do
      it 'validates uniqueness of name scoped to company' do
        create(:category, name: 'Test Category', company: company)
        duplicate = build(:category, name: 'Test Category', company: company)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include('has already been taken')
      end

      it 'allows same name in different companies' do
        create(:category, name: 'Test Category', company: company)
        other_company = create(:company)
        duplicate = build(:category, name: 'Test Category', company: other_company)
        expect(duplicate).to be_valid
      end

      it 'allows same name if original is soft deleted' do
        original = create(:category, name: 'Unique Category', company: company)
        original.soft_delete!
        duplicate = build(:category, name: 'Unique Category', company: company)
        expect(duplicate).to be_valid
      end
    end
  end

  describe 'scopes' do
    before do
      @active_category = create(:category, company: company, active: true, name: 'Active Category')
      @inactive_category = create(:category, company: company, active: false, name: 'Inactive Category')
      @deleted_category = create(:category, company: company, name: 'Deleted Category')
      @deleted_category.soft_delete!
    end

    describe '.active' do
      it 'returns only active categories' do
        expect(Category.active).to include(@active_category)
        expect(Category.active).not_to include(@inactive_category)
      end
    end

    describe '.not_deleted' do
      it 'returns only non-deleted categories' do
        expect(Category.not_deleted).to include(@active_category, @inactive_category)
        expect(Category.not_deleted).not_to include(@deleted_category)
      end
    end

    describe '.ordered' do
      it 'orders by sort_order and name' do
        # Create a fresh company to avoid interference from other tests
        test_company = create(:company)
        cat1 = create(:category, company: test_company, sort_order: 2, name: 'B')
        cat2 = create(:category, company: test_company, sort_order: 1, name: 'A')
        cat3 = create(:category, company: test_company, sort_order: 1, name: 'C')

        expect(Category.where(company: test_company).ordered).to eq([ cat2, cat3, cat1 ])
      end
    end
  end

  describe 'tenant behavior' do
    it 'acts as tenant' do
      expect(Category.new).to respond_to(:company_id)
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at timestamp' do
      category.save!
      expect { category.soft_delete! }.to change { category.deleted_at }.from(nil)
    end

    it 'does not actually destroy the record' do
      category.save!
      expect { category.soft_delete! }.not_to change { Category.count }
    end
  end

  describe '#deleted?' do
    it 'returns false when deleted_at is nil' do
      expect(category.deleted?).to be false
    end

    it 'returns true when deleted_at is present' do
      category.deleted_at = Time.current
      expect(category.deleted?).to be true
    end
  end
end
