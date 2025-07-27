require 'rails_helper'

RSpec.describe SalesOrder, type: :model do
  let(:company) { create(:company) }
  let(:payment_method) { create(:payment_method, company: company) }
  let(:sales_order) { build(:sales_order, company: company, payment_method: payment_method) }

  describe 'associations' do
    it { should belong_to(:company) }
    it { should belong_to(:payment_method) }
    it { should have_many(:sales_order_items).dependent(:destroy) }
    it { should have_many(:items).through(:sales_order_items) }
  end

  describe 'validations' do
    subject { sales_order }

    it { should validate_presence_of(:order_no) }
    it { should validate_presence_of(:sub_total) }
    it { should validate_numericality_of(:sub_total).is_greater_than(0) }
    it { should validate_presence_of(:grand_total) }
    it { should validate_numericality_of(:grand_total).is_greater_than(0) }
    it { should validate_presence_of(:paid_amount) }
    it { should validate_numericality_of(:paid_amount).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:status) }

    context 'uniqueness validation' do
      it 'validates uniqueness of order_no scoped to company' do
        create(:sales_order, order_no: 'SO-001', company: company, payment_method: payment_method)
        duplicate = build(:sales_order, order_no: 'SO-001', company: company, payment_method: payment_method)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:order_no]).to include('has already been taken')
      end

      it 'allows same order_no in different companies' do
        create(:sales_order, order_no: 'SO-001', company: company, payment_method: payment_method)
        other_company = create(:company)
        other_payment_method = create(:payment_method, company: other_company)
        duplicate = build(:sales_order, order_no: 'SO-001', company: other_company, payment_method: other_payment_method)
        expect(duplicate).to be_valid
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, completed: 1, voided: 2) }
  end

  describe 'scopes' do
    before do
      @recent_order = create(:sales_order, company: company, payment_method: payment_method, created_at: 1.hour.ago, order_no: 'RECENT-001')
      @old_order = create(:sales_order, company: company, payment_method: payment_method, created_at: 1.week.ago, order_no: 'OLD-001')
      @deleted_order = create(:sales_order, company: company, payment_method: payment_method, order_no: 'DELETED-001')
      @deleted_order.soft_delete!
    end

    describe '.not_deleted' do
      it 'returns only non-deleted orders' do
        expect(SalesOrder.not_deleted).to include(@recent_order, @old_order)
        expect(SalesOrder.not_deleted).not_to include(@deleted_order)
      end
    end

    describe '.recent' do
      it 'orders by created_at desc' do
        expect(SalesOrder.where(company: company).not_deleted.recent.first).to eq(@recent_order)
      end
    end
  end

  describe 'tenant behavior' do
    it 'acts as tenant' do
      expect(SalesOrder.new).to respond_to(:company_id)
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at timestamp' do
      sales_order.save!
      expect { sales_order.soft_delete! }.to change { sales_order.deleted_at }.from(nil)
    end

    it 'does not actually destroy the record' do
      sales_order.save!
      expect { sales_order.soft_delete! }.not_to change { SalesOrder.count }
    end
  end

  describe '#deleted?' do
    it 'returns false when deleted_at is nil' do
      expect(sales_order.deleted?).to be false
    end

    it 'returns true when deleted_at is present' do
      sales_order.deleted_at = Time.current
      expect(sales_order.deleted?).to be true
    end
  end

  describe '#total_items' do
    it 'returns sum of quantities from order items' do
      sales_order.save!
      create(:sales_order_item, sales_order: sales_order, quantity: 2)
      create(:sales_order_item, sales_order: sales_order, quantity: 3)
      expect(sales_order.total_items).to eq(5)
    end

    it 'returns 0 when no items' do
      sales_order.save!
      expect(sales_order.total_items).to eq(0)
    end
  end

  describe '#can_be_voided?' do
    it 'returns true for completed orders created within 24 hours' do
      sales_order.status = 'completed'
      sales_order.created_at = 1.hour.ago
      expect(sales_order.can_be_voided?).to be true
    end

    it 'returns false for completed orders older than 24 hours' do
      sales_order.status = 'completed'
      sales_order.created_at = 25.hours.ago
      expect(sales_order.can_be_voided?).to be false
    end

    it 'returns false for pending orders' do
      sales_order.status = 'pending'
      sales_order.created_at = 1.hour.ago
      expect(sales_order.can_be_voided?).to be false
    end

    it 'returns false for voided orders' do
      sales_order.status = 'voided'
      sales_order.created_at = 1.hour.ago
      expect(sales_order.can_be_voided?).to be false
    end
  end

  describe '#void!' do
    let(:sales_order_item) { instance_double('SalesOrderItem') }

    before do
      sales_order.save!
      allow(sales_order).to receive(:sales_order_items).and_return([ sales_order_item ])
      allow(sales_order_item).to receive(:revert_inventory!)
    end

    context 'when order can be voided' do
      before do
        sales_order.update!(status: 'completed', created_at: 1.hour.ago)
      end

      it 'changes status to voided' do
        expect { sales_order.void! }.to change { sales_order.status }.from('completed').to('voided')
      end

      it 'calls revert_inventory! on each order item' do
        expect(sales_order_item).to receive(:revert_inventory!)
        sales_order.void!
      end
    end

    context 'when order cannot be voided' do
      before do
        sales_order.update!(status: 'pending')
      end

      it 'raises an error' do
        expect { sales_order.void! }.to raise_error('Cannot void this order')
      end
    end
  end
end
