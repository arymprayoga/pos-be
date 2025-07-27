require 'rails_helper'

RSpec.describe Permission, type: :model do
  let(:company) { create(:company) }

  describe 'validations' do
    subject { build(:permission, company: company) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:resource) }
    it { is_expected.to validate_presence_of(:action) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:company_id) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to have_and_belong_to_many(:users) }
  end

  describe 'scopes' do
    let!(:inventory_permission) { create(:permission, company: company, resource: 'inventory', action: 'manage_stock') }
    let!(:transaction_permission) { create(:permission, company: company, resource: 'transactions', action: 'create') }
    let!(:system_permission) { create(:permission, company: company, system_permission: true) }

    describe '.for_resource' do
      it 'returns permissions for specific resource' do
        expect(Permission.for_resource('inventory')).to contain_exactly(inventory_permission)
      end
    end

    describe '.for_action' do
      it 'returns permissions for specific action' do
        expect(Permission.for_action('manage_stock')).to contain_exactly(inventory_permission)
      end
    end

    describe '.system_permissions' do
      it 'returns only system permissions' do
        expect(Permission.system_permissions).to contain_exactly(system_permission)
      end
    end
  end

  describe '.create_system_permissions_for_company' do
    it 'creates all system permissions for a company' do
      expect {
        Permission.create_system_permissions_for_company(company)
      }.to change { company.permissions.count }.by_at_least(20)
    end

    it 'creates permissions for all defined resources' do
      Permission.create_system_permissions_for_company(company)

      Permission::SYSTEM_PERMISSIONS.each do |resource, actions|
        actions.each do |action|
          expect(company.permissions.find_by(resource: resource, action: action)).to be_present
        end
      end
    end

    it 'does not create duplicate permissions' do
      Permission.create_system_permissions_for_company(company)
      initial_count = company.permissions.count

      Permission.create_system_permissions_for_company(company)
      expect(company.permissions.count).to eq(initial_count)
    end
  end

  describe '#full_name' do
    let(:permission) { build(:permission, resource: 'transactions', action: 'void') }

    it 'returns resource.action format' do
      expect(permission.full_name).to eq('transactions.void')
    end
  end

  describe '#system?' do
    it 'returns true for system permissions' do
      permission = build(:permission, system_permission: true)
      expect(permission).to be_system
    end

    it 'returns false for custom permissions' do
      permission = build(:permission, system_permission: false)
      expect(permission).not_to be_system
    end
  end
end
