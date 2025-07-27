require 'rails_helper'

RSpec.describe Tax, type: :model do
  let(:company) { create(:company) }
  let(:tax) { build(:tax, company: company) }

  describe 'associations' do
    it { should belong_to(:company) }
  end

  describe 'validations' do
    subject { tax }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:rate) }
    it { should validate_numericality_of(:rate).is_greater_than_or_equal_to(0).is_less_than(1) }

    context 'uniqueness validation' do
      it 'validates uniqueness of name scoped to company' do
        create(:tax, name: 'VAT', company: company)
        duplicate = build(:tax, name: 'VAT', company: company)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include('has already been taken')
      end

      it 'allows same name in different companies' do
        create(:tax, name: 'VAT', company: company)
        other_company = create(:company)
        duplicate = build(:tax, name: 'VAT', company: other_company)
        expect(duplicate).to be_valid
      end

      it 'allows same name if original is soft deleted' do
        original = create(:tax, name: 'Unique Tax', company: company)
        original.soft_delete!
        duplicate = build(:tax, name: 'Unique Tax', company: company)
        expect(duplicate).to be_valid
      end
    end
  end

  describe 'scopes' do
    before do
      @active_tax = create(:tax, name: 'Active Tax', company: company, active: true)
      @inactive_tax = create(:tax, name: 'Inactive Tax', company: company, active: false)
      @default_tax = create(:tax, name: 'Default Tax', company: company, is_default: true)
      @deleted_tax = create(:tax, name: 'Deleted Tax', company: company)
      @deleted_tax.soft_delete!
    end

    describe '.active' do
      it 'returns only active taxes' do
        expect(Tax.active).to include(@active_tax)
        expect(Tax.active).not_to include(@inactive_tax)
      end
    end

    describe '.not_deleted' do
      it 'returns only non-deleted taxes' do
        expect(Tax.not_deleted).to include(@active_tax, @inactive_tax, @default_tax)
        expect(Tax.not_deleted).not_to include(@deleted_tax)
      end
    end

    describe '.default' do
      it 'returns only default taxes' do
        expect(Tax.default).to include(@default_tax)
        expect(Tax.default).not_to include(@active_tax, @inactive_tax)
      end
    end
  end

  describe 'tenant behavior' do
    it 'acts as tenant' do
      expect(Tax.new).to respond_to(:company_id)
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at timestamp' do
      tax.save!
      expect { tax.soft_delete! }.to change { tax.deleted_at }.from(nil)
    end

    it 'does not actually destroy the record' do
      tax.save!
      expect { tax.soft_delete! }.not_to change { Tax.count }
    end
  end

  describe '#deleted?' do
    it 'returns false when deleted_at is nil' do
      expect(tax.deleted?).to be false
    end

    it 'returns true when deleted_at is present' do
      tax.deleted_at = Time.current
      expect(tax.deleted?).to be true
    end
  end

  describe '#rate_percentage' do
    it 'converts decimal rate to percentage' do
      tax.rate = 0.15
      expect(tax.rate_percentage).to eq(15.0)
    end

    it 'rounds to 2 decimal places' do
      tax.rate = 0.12345
      expect(tax.rate_percentage).to eq(12.35)
    end

    it 'handles zero rate' do
      tax.rate = 0.0
      expect(tax.rate_percentage).to eq(0.0)
    end
  end
end
