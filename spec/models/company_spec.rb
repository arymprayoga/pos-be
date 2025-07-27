require 'rails_helper'

RSpec.describe Company, type: :model do
  let(:company) { build(:company) }

  describe 'associations' do
    it { should have_many(:users).dependent(:destroy) }
    it { should have_many(:categories).dependent(:destroy) }
    it { should have_many(:items).dependent(:destroy) }
    it { should have_many(:inventories).dependent(:destroy) }
    it { should have_many(:taxes).dependent(:destroy) }
    it { should have_many(:payment_methods).dependent(:destroy) }
    it { should have_many(:sales_orders).dependent(:destroy) }
    it { should have_many(:inventory_ledgers).dependent(:destroy) }
  end

  describe 'validations' do
    subject { company }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:currency) }
    it { should validate_presence_of(:timezone) }

    context 'uniqueness validation' do
      it 'validates uniqueness of email' do
        create(:company, email: 'test@company.com')
        duplicate = build(:company, email: 'test@company.com')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:email]).to include('has already been taken')
      end

      it 'allows same email if original is soft deleted' do
        original = create(:company, email: 'unique@company.com')
        original.soft_delete!
        duplicate = build(:company, email: 'unique@company.com')
        expect(duplicate).to be_valid
      end
    end
  end

  describe 'scopes' do
    before do
      @active_company = create(:company, active: true)
      @inactive_company = create(:company, active: false)
      @deleted_company = create(:company)
      @deleted_company.soft_delete!
    end

    describe '.active' do
      it 'returns only active companies' do
        expect(Company.active).to include(@active_company)
        expect(Company.active).not_to include(@inactive_company)
      end
    end

    describe '.not_deleted' do
      it 'returns only non-deleted companies' do
        expect(Company.not_deleted).to include(@active_company, @inactive_company)
        expect(Company.not_deleted).not_to include(@deleted_company)
      end
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at timestamp' do
      company.save!
      expect { company.soft_delete! }.to change { company.deleted_at }.from(nil)
    end

    it 'does not actually destroy the record' do
      company.save!
      expect { company.soft_delete! }.not_to change { Company.count }
    end
  end

  describe '#deleted?' do
    it 'returns false when deleted_at is nil' do
      expect(company.deleted?).to be false
    end

    it 'returns true when deleted_at is present' do
      company.deleted_at = Time.current
      expect(company.deleted?).to be true
    end
  end
end
