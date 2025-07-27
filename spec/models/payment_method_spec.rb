require 'rails_helper'

RSpec.describe PaymentMethod, type: :model do
  let(:company) { create(:company) }
  let(:payment_method) { build(:payment_method, company: company) }

  describe 'associations' do
    it { should belong_to(:company) }
    it { should have_many(:sales_orders).dependent(:restrict_with_error) }
  end

  describe 'validations' do
    subject { payment_method }

    it { should validate_presence_of(:name) }

    context 'uniqueness validation' do
      it 'validates uniqueness of name scoped to company' do
        create(:payment_method, name: 'Cash', company: company)
        duplicate = build(:payment_method, name: 'Cash', company: company)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:name]).to include('has already been taken')
      end

      it 'allows same name in different companies' do
        create(:payment_method, name: 'Cash', company: company)
        other_company = create(:company)
        duplicate = build(:payment_method, name: 'Cash', company: other_company)
        expect(duplicate).to be_valid
      end

      it 'allows same name if original is soft deleted' do
        original = create(:payment_method, name: 'Unique Payment', company: company)
        original.soft_delete!
        duplicate = build(:payment_method, name: 'Unique Payment', company: company)
        expect(duplicate).to be_valid
      end
    end
  end

  describe 'scopes' do
    before do
      @active_method = create(:payment_method, company: company, active: true, name: 'Active Method')
      @inactive_method = create(:payment_method, company: company, active: false, name: 'Inactive Method')
      @default_method = create(:payment_method, company: company, is_default: true, name: 'Default Method')
      @deleted_method = create(:payment_method, company: company, name: 'Deleted Method')
      @deleted_method.soft_delete!
    end

    describe '.active' do
      it 'returns only active payment methods' do
        expect(PaymentMethod.active).to include(@active_method)
        expect(PaymentMethod.active).not_to include(@inactive_method)
      end
    end

    describe '.not_deleted' do
      it 'returns only non-deleted payment methods' do
        expect(PaymentMethod.not_deleted).to include(@active_method, @inactive_method, @default_method)
        expect(PaymentMethod.not_deleted).not_to include(@deleted_method)
      end
    end

    describe '.default' do
      it 'returns only default payment methods' do
        expect(PaymentMethod.default).to include(@default_method)
        expect(PaymentMethod.default).not_to include(@active_method, @inactive_method)
      end
    end

    describe '.ordered' do
      it 'orders by sort_order and name' do
        test_company = create(:company)
        method1 = create(:payment_method, company: test_company, sort_order: 2, name: 'Credit Card')
        method2 = create(:payment_method, company: test_company, sort_order: 1, name: 'Cash')
        method3 = create(:payment_method, company: test_company, sort_order: 1, name: 'Debit Card')

        expect(PaymentMethod.where(company: test_company).ordered).to eq([ method2, method3, method1 ])
      end
    end
  end

  describe 'tenant behavior' do
    it 'acts as tenant' do
      expect(PaymentMethod.new).to respond_to(:company_id)
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at timestamp' do
      payment_method.save!
      expect { payment_method.soft_delete! }.to change { payment_method.deleted_at }.from(nil)
    end

    it 'does not actually destroy the record' do
      payment_method.save!
      expect { payment_method.soft_delete! }.not_to change { PaymentMethod.count }
    end
  end

  describe '#deleted?' do
    it 'returns false when deleted_at is nil' do
      expect(payment_method.deleted?).to be false
    end

    it 'returns true when deleted_at is present' do
      payment_method.deleted_at = Time.current
      expect(payment_method.deleted?).to be true
    end
  end
end
