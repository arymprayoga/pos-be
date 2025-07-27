require 'rails_helper'

RSpec.describe User, type: :model do
  let(:company) { create(:company) }
  let(:user) { build(:user, company: company) }

  describe 'associations' do
    it { should belong_to(:company) }
  end

  describe 'validations' do
    subject { user }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:role) }
    it { should have_secure_password }

    context 'uniqueness validation' do
      it 'validates uniqueness of email scoped to company' do
        create(:user, email: 'test@example.com', company: company)
        duplicate = build(:user, email: 'test@example.com', company: company)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:email]).to include('has already been taken')
      end

      it 'allows same email in different companies' do
        create(:user, email: 'test@example.com', company: company)
        other_company = create(:company)
        duplicate = build(:user, email: 'test@example.com', company: other_company)
        expect(duplicate).to be_valid
      end

      it 'allows same email if original is soft deleted' do
        original = create(:user, email: 'unique@example.com', company: company)
        original.soft_delete!
        duplicate = build(:user, email: 'unique@example.com', company: company)
        expect(duplicate).to be_valid
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(cashier: 0, manager: 1, owner: 2) }
  end

  describe 'scopes' do
    before do
      @active_user = create(:user, company: company, active: true)
      @inactive_user = create(:user, company: company, active: false)
      @deleted_user = create(:user, company: company)
      @deleted_user.soft_delete!
    end

    describe '.active' do
      it 'returns only active users' do
        expect(User.active).to include(@active_user)
        expect(User.active).not_to include(@inactive_user)
      end
    end

    describe '.not_deleted' do
      it 'returns only non-deleted users' do
        expect(User.not_deleted).to include(@active_user, @inactive_user)
        expect(User.not_deleted).not_to include(@deleted_user)
      end
    end
  end

  describe 'tenant behavior' do
    it 'acts as tenant' do
      expect(User.new).to respond_to(:company_id)
    end
  end

  describe '#soft_delete!' do
    it 'sets deleted_at timestamp' do
      user.save!
      expect { user.soft_delete! }.to change { user.deleted_at }.from(nil)
    end

    it 'does not actually destroy the record' do
      user.save!
      expect { user.soft_delete! }.not_to change { User.count }
    end
  end

  describe '#deleted?' do
    it 'returns false when deleted_at is nil' do
      expect(user.deleted?).to be false
    end

    it 'returns true when deleted_at is present' do
      user.deleted_at = Time.current
      expect(user.deleted?).to be true
    end
  end

  describe 'permission methods' do
    describe '#can_manage_inventory?' do
      it 'returns true for managers' do
        user.role = 'manager'
        expect(user.can_manage_inventory?).to be true
      end

      it 'returns true for owners' do
        user.role = 'owner'
        expect(user.can_manage_inventory?).to be true
      end

      it 'returns false for cashiers' do
        user.role = 'cashier'
        expect(user.can_manage_inventory?).to be false
      end
    end

    describe '#can_access_reports?' do
      it 'returns true for managers' do
        user.role = 'manager'
        expect(user.can_access_reports?).to be true
      end

      it 'returns true for owners' do
        user.role = 'owner'
        expect(user.can_access_reports?).to be true
      end

      it 'returns false for cashiers' do
        user.role = 'cashier'
        expect(user.can_access_reports?).to be false
      end
    end

    describe '#can_void_transactions?' do
      it 'returns true for managers' do
        user.role = 'manager'
        expect(user.can_void_transactions?).to be true
      end

      it 'returns true for owners' do
        user.role = 'owner'
        expect(user.can_void_transactions?).to be true
      end

      it 'returns false for cashiers' do
        user.role = 'cashier'
        expect(user.can_void_transactions?).to be false
      end
    end

    describe '#can_override_prices?' do
      it 'returns true for managers' do
        user.role = 'manager'
        expect(user.can_override_prices?).to be true
      end

      it 'returns true for owners' do
        user.role = 'owner'
        expect(user.can_override_prices?).to be true
      end

      it 'returns false for cashiers' do
        user.role = 'cashier'
        expect(user.can_override_prices?).to be false
      end
    end
  end
end
