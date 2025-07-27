require 'rails_helper'

RSpec.describe Authorizable, type: :concern do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  before do
    # Setup permissions for the company
    Permission.create_system_permissions_for_company(company)
  end

  shared_examples 'authorizable entity' do
    it 'has permissions association' do
      expect(subject.class.reflect_on_association(:permissions)).to be_present
      expect(subject.class.reflect_on_association(:permissions).macro).to eq(:has_and_belongs_to_many)
    end
  end

  describe 'included in User model' do
    subject { user }

    it_behaves_like 'authorizable entity'

    describe '#has_permission?' do
      let!(:read_permission) { company.permissions.find_by(resource: 'transactions', action: 'read') }
      let!(:void_permission) { company.permissions.find_by(resource: 'transactions', action: 'void') }

      context 'owner user' do
        let(:user) { create(:user, :owner, company: company) }

        it 'always returns true for any permission' do
          expect(user.has_permission?('transactions', 'void')).to be true
          expect(user.has_permission?('reports', 'export')).to be true
          expect(user.has_permission?('anything', 'anything')).to be true
        end
      end

      context 'non-owner user with specific permissions' do
        before do
          user.permissions << read_permission
        end

        it 'returns true for granted permissions' do
          expect(user.has_permission?('transactions', 'read')).to be true
        end

        it 'returns false for non-granted permissions' do
          expect(user.has_permission?('transactions', 'void')).to be false
        end

        it 'falls back to role permissions' do
          user.update!(role: 'manager')
          expect(user.has_permission?('transactions', 'void')).to be true # Manager default permission
        end
      end
    end

    describe '#has_any_permission?' do
      let!(:read_permission) { company.permissions.find_by(resource: 'transactions', action: 'read') }

      before { user.permissions << read_permission }

      it 'returns true if user has any of the specified permissions' do
        result = user.has_any_permission?(
          [ 'transactions', 'read' ],
          [ 'transactions', 'void' ],
          [ 'reports', 'export' ]
        )
        expect(result).to be true
      end

      it 'returns false if user has none of the specified permissions' do
        result = user.has_any_permission?(
          [ 'transactions', 'void' ],
          [ 'reports', 'export' ]
        )
        expect(result).to be false
      end
    end

    describe '#has_all_permissions?' do
      let!(:read_permission) { company.permissions.find_by(resource: 'transactions', action: 'read') }
      let!(:create_permission) { company.permissions.find_by(resource: 'transactions', action: 'create') }

      before { user.permissions << [ read_permission, create_permission ] }

      it 'returns true if user has all specified permissions' do
        result = user.has_all_permissions?(
          [ 'transactions', 'read' ],
          [ 'transactions', 'create' ]
        )
        expect(result).to be true
      end

      it 'returns false if user is missing any permission' do
        result = user.has_all_permissions?(
          [ 'transactions', 'read' ],
          [ 'transactions', 'void' ]
        )
        expect(result).to be false
      end
    end

    describe '#can?' do
      let!(:read_permission) { company.permissions.find_by(resource: 'transactions', action: 'read') }

      before { user.permissions << read_permission }

      context 'with string/symbol resource' do
        it 'checks permission directly' do
          expect(user.can?(:read, :transactions)).to be true
          expect(user.can?(:read, 'transactions')).to be true
          expect(user.can?(:void, :transactions)).to be false
        end
      end

      context 'with class resource' do
        it 'checks permission using tableized class name' do
          # Create a mock class that behaves like ActiveRecord
          transaction_class = Class.new do
            def self.name
              'Transaction'
            end

            def self.tableize
              'transactions'
            end
          end

          expect(user.can?(:read, transaction_class)).to be true
        end
      end

      context 'with instance resource' do
        let(:transaction_instance) { double('transaction', class: double(name: 'Transaction')) }

        it 'checks permission using tableized class name' do
          allow(transaction_instance.class).to receive(:tableize) { 'transactions' }
          expect(user.can?(:read, transaction_instance)).to be true
        end
      end

      context 'owner user' do
        let(:user) { create(:user, :owner, company: company) }

        it 'always returns true' do
          expect(user.can?(:anything, :anything)).to be true
        end
      end
    end

    describe '#cannot?' do
      it 'returns opposite of can?' do
        allow(user).to receive(:can?).with(:read, :transactions).and_return(true)
        allow(user).to receive(:can?).with(:void, :transactions).and_return(false)

        expect(user.cannot?(:read, :transactions)).to be false
        expect(user.cannot?(:void, :transactions)).to be true
      end
    end

    describe '#grant_permission!' do
      let!(:void_permission) { company.permissions.find_by(resource: 'transactions', action: 'void') }

      it 'grants permission to user' do
        expect {
          user.grant_permission!('transactions', 'void')
        }.to change { user.permissions.count }.by(1)

        expect(user.has_permission?('transactions', 'void')).to be true
      end

      it 'does not grant duplicate permissions' do
        user.permissions << void_permission

        expect {
          user.grant_permission!('transactions', 'void')
        }.not_to change { user.permissions.count }
      end

      it 'does nothing if permission does not exist' do
        expect {
          user.grant_permission!('nonexistent', 'action')
        }.not_to change { user.permissions.count }
      end
    end

    describe '#revoke_permission!' do
      let!(:void_permission) { company.permissions.find_by(resource: 'transactions', action: 'void') }

      before { user.permissions << void_permission }

      it 'revokes permission from user' do
        expect {
          user.revoke_permission!('transactions', 'void')
        }.to change { user.permissions.count }.by(-1)

        expect(user.has_permission?('transactions', 'void')).to be false
      end

      it 'does nothing if user does not have permission' do
        user.permissions.clear

        expect {
          user.revoke_permission!('transactions', 'void')
        }.not_to change { user.permissions.count }
      end
    end

    describe '#grant_role_permissions!' do
      it 'grants default permissions for cashier role' do
        user.grant_role_permissions!('cashier')

        expect(user.can?(:read, :transactions)).to be true
        expect(user.can?(:create, :transactions)).to be true
        expect(user.can?(:read, :items)).to be true
      end

      it 'grants default permissions for manager role' do
        expect {
          user.grant_role_permissions!('manager')
        }.to change { user.permissions.count }.by_at_least(10)

        expect(user.can?(:void, :transactions)).to be true
        expect(user.can?(:override_price, :transactions)).to be true
        expect(user.can?(:read, :reports)).to be true
      end

      it 'grants all permissions for owner role' do
        expect {
          user.grant_role_permissions!('owner')
        }.to change { user.permissions.count }.by_at_least(20)

        expect(user.can?(:create, :users)).to be true
        expect(user.can?(:update, :settings)).to be true
      end
    end

    describe '#revoke_all_permissions!' do
      let!(:permissions) { company.permissions.limit(3) }

      before { user.permissions << permissions }

      it 'removes all permissions from user' do
        expect {
          user.revoke_all_permissions!
        }.to change { user.permissions.count }.to(0)
      end
    end

    describe '#permission_list' do
      let!(:permission) { company.permissions.find_by(resource: 'transactions', action: 'void') }

      before { user.permissions << permission }

      it 'returns formatted permission list' do
        list = user.permission_list

        expect(list).to be_an(Array)
        expect(list.first).to include(
          :id, :name, :resource, :action, :description, :system
        )
        expect(list.first[:resource]).to eq('transactions')
        expect(list.first[:action]).to eq('void')
      end
    end

    describe '#role_permissions_summary' do
      let!(:transaction_read) { company.permissions.find_by(resource: 'transactions', action: 'read') }
      let!(:transaction_void) { company.permissions.find_by(resource: 'transactions', action: 'void') }
      let!(:inventory_read) { company.permissions.find_by(resource: 'inventory', action: 'read') }

      before { user.permissions << [ transaction_read, transaction_void, inventory_read ] }

      it 'returns permissions grouped by resource' do
        summary = user.role_permissions_summary

        expect(summary['transactions']).to include('read', 'void')
        expect(summary['inventory']).to include('read')
        expect(summary['transactions'].sort).to eq(summary['transactions'])
      end
    end

    describe 'authorization helper methods' do
      context 'cashier user' do
        let(:user) { create(:user, :cashier, company: company) }

        it 'has limited permissions' do
          expect(user.can_manage_inventory?).to be false
          expect(user.can_access_reports?).to be false
          expect(user.can_void_transactions?).to be false
          expect(user.can_override_prices?).to be false
          expect(user.can_manage_users?).to be false
          expect(user.can_assign_roles?).to be false
          expect(user.can_manage_settings?).to be false
        end
      end

      context 'manager user' do
        let(:user) { create(:user, :manager, company: company) }

        it 'has intermediate permissions' do
          expect(user.can_manage_inventory?).to be true
          expect(user.can_access_reports?).to be true
          expect(user.can_void_transactions?).to be true
          expect(user.can_override_prices?).to be true
          expect(user.can_manage_users?).to be false
          expect(user.can_assign_roles?).to be false
          expect(user.can_manage_settings?).to be false
        end
      end

      context 'owner user' do
        let(:user) { create(:user, :owner, company: company) }

        it 'has all permissions' do
          expect(user.can_manage_inventory?).to be true
          expect(user.can_access_reports?).to be true
          expect(user.can_void_transactions?).to be true
          expect(user.can_override_prices?).to be true
          expect(user.can_manage_users?).to be true
          expect(user.can_assign_roles?).to be true
          expect(user.can_manage_settings?).to be true
        end
      end

      context 'user with custom permissions' do
        let!(:inventory_permission) { company.permissions.find_by(resource: 'inventory', action: 'manage_stock') }

        before { user.permissions << inventory_permission }

        it 'respects custom permissions' do
          expect(user.can_manage_inventory?).to be true
        end
      end
    end
  end
end
