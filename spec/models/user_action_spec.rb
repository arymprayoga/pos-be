require 'rails_helper'

RSpec.describe UserAction, type: :model do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:user_session) { create(:user_session, user: user, company: company) }

  describe 'validations' do
    subject { build(:user_action, company: company, user: user, user_session: user_session) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:action) }
    it { is_expected.to validate_presence_of(:resource_type) }
    it { is_expected.to validate_presence_of(:ip_address) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:company) }

    it 'belongs to user optionally' do
      expect(subject.class.reflect_on_association(:user)).to be_present
      # Check if the association allows nil values by validating the presence
      user_action = UserAction.new(
        company: company,
        action: 'test',
        resource_type: 'Test',
        ip_address: '127.0.0.1',
        user_agent: 'test'
      )
      expect(user_action.valid?).to be true
    end

    it 'belongs to user_session optionally' do
      expect(subject.class.reflect_on_association(:user_session)).to be_present
      expect(subject.class.reflect_on_association(:user_session).options[:optional]).to be true
    end
  end

  describe 'scopes' do
    let!(:login_action) { create(:user_action, :login, user: user, company: company) }
    let!(:transaction_action) { create(:user_action, :sensitive, user: user, company: company) }
    let!(:failed_action) { create(:user_action, :failed, user: user, company: company) }
    let!(:other_user_action) { create(:user_action, company: company) }

    describe '.recent' do
      it 'orders by created_at desc' do
        expect(UserAction.recent.first).to eq(UserAction.order(created_at: :desc).first)
      end
    end

    describe '.for_user' do
      it 'returns actions for specific user' do
        expect(UserAction.for_user(user)).to include(login_action, transaction_action, failed_action)
        expect(UserAction.for_user(user)).not_to include(other_user_action)
      end
    end

    describe '.for_action' do
      it 'returns actions of specific type' do
        expect(UserAction.for_action('login_success')).to contain_exactly(login_action)
      end
    end

    describe '.for_resource' do
      it 'returns actions for specific resource type' do
        expect(UserAction.for_resource('Authentication')).to include(login_action)
        expect(UserAction.for_resource('Transaction')).to include(transaction_action)
      end
    end

    describe '.sensitive' do
      it 'returns only sensitive actions' do
        expect(UserAction.sensitive).to contain_exactly(transaction_action)
      end
    end

    describe '.by_date_range' do
      let!(:old_action) { create(:user_action, created_at: 2.days.ago) }
      let!(:recent_action) { create(:user_action, created_at: 1.hour.ago) }

      it 'returns actions within date range' do
        range = 1.day.ago..Time.current
        expect(UserAction.by_date_range(range.begin, range.end)).to include(recent_action)
        expect(UserAction.by_date_range(range.begin, range.end)).not_to include(old_action)
      end
    end

    describe '.today' do
      let!(:today_action) { create(:user_action, created_at: 2.hours.ago) }
      let!(:yesterday_action) { create(:user_action, created_at: 1.day.ago) }

      it 'returns actions from today only' do
        expect(UserAction.today).to include(today_action)
        expect(UserAction.today).not_to include(yesterday_action)
      end
    end
  end

  describe '.log_action' do
    let(:request) { double('request', remote_ip: '192.168.1.1', user_agent: 'Test Browser') }

    it 'creates a successful action log' do
      expect {
        UserAction.log_action(
          user: user,
          action: 'test_action',
          resource_type: 'TestResource',
          resource_id: '123',
          details: { test: 'data' },
          request: request,
          user_session: user_session
        )
      }.to change { UserAction.count }.by(1)

      action = UserAction.last
      expect(action.user).to eq(user)
      expect(action.action).to eq('test_action')
      expect(action.resource_type).to eq('TestResource')
      expect(action.resource_id).to eq('123')
      expect(action.details['test']).to eq('data')
      expect(action.success).to be true
      expect(action.ip_address).to eq('192.168.1.1')
      expect(action.user_agent).to eq('Test Browser')
    end

    it 'sanitizes sensitive details' do
      UserAction.log_action(
        user: user,
        action: 'test_action',
        resource_type: 'TestResource',
        details: { 'password' => 'secret', 'token' => 'jwt_token', 'data' => 'safe' },
        request: request
      )

      action = UserAction.last
      expect(action.details).not_to have_key('password')
      expect(action.details).not_to have_key('token')
      expect(action.details['data']).to eq('safe')
    end

    it 'does not raise error on failure' do
      allow(UserAction).to receive(:create!).and_raise(StandardError, 'Database error')

      expect {
        UserAction.log_action(
          user: user,
          action: 'test_action',
          resource_type: 'TestResource',
          request: request
        )
      }.not_to raise_error
    end
  end

  describe '.log_failed_action' do
    let(:request) { double('request', remote_ip: '192.168.1.1', user_agent: 'Test Browser') }

    it 'creates a failed action log' do
      UserAction.log_failed_action(
        user: user,
        action: 'login',
        resource_type: 'Authentication',
        error: 'Invalid credentials',
        request: request
      )

      action = UserAction.last
      expect(action.success).to be false
      expect(action.details['error']).to eq('Invalid credentials')
    end

    it 'allows nil user for failed login attempts' do
      expect {
        UserAction.log_failed_action(
          user: nil,
          action: 'login',
          resource_type: 'Authentication',
          error: 'Invalid credentials',
          request: request
        )
      }.not_to raise_error
    end
  end

  describe '.audit_trail_for_resource' do
    let!(:transaction1) { create(:user_action, resource_type: 'Transaction', resource_id: '123') }
    let!(:transaction2) { create(:user_action, resource_type: 'Transaction', resource_id: '123') }
    let!(:other_transaction) { create(:user_action, resource_type: 'Transaction', resource_id: '456') }

    it 'returns audit trail for specific resource' do
      trail = UserAction.audit_trail_for_resource('Transaction', '123')
      expect(trail).to include(transaction1, transaction2)
      expect(trail).not_to include(other_transaction)
    end

    it 'includes user information' do
      trail = UserAction.audit_trail_for_resource('Transaction', '123')
      expect(trail.first.association(:user)).to be_loaded
    end

    it 'limits results' do
      trail = UserAction.audit_trail_for_resource('Transaction', '123', limit: 1)
      expect(trail.count).to eq(1)
    end
  end

  describe '.user_activity_summary' do
    let!(:success_action) { create(:user_action, user: user, success: true) }
    let!(:failed_action) { create(:user_action, user: user, success: false) }
    let!(:sensitive_action) { create(:user_action, :sensitive, user: user) }

    it 'returns activity summary for user' do
      summary = UserAction.user_activity_summary(user)

      expect(summary[:total_actions]).to eq(3)
      expect(summary[:successful_actions]).to eq(2)
      expect(summary[:failed_actions]).to eq(1)
      expect(summary[:sensitive_actions]).to eq(1)
      expect(summary[:most_common_actions]).to be_present
      expect(summary[:daily_activity]).to be_present
    end
  end

  describe 'instance methods' do
    let(:action) { create(:user_action, :sensitive, user: user, company: company) }

    describe '#sensitive?' do
      it 'returns true for sensitive actions' do
        expect(action).to be_sensitive
      end

      it 'returns false for non-sensitive actions' do
        regular_action = create(:user_action, action: 'read_item', user: user, company: company)
        expect(regular_action).not_to be_sensitive
      end
    end

    describe '#action_category' do
      it 'returns correct category for authentication actions' do
        login_action = create(:user_action, action: 'login', user: user, company: company)
        expect(login_action.action_category).to eq(:authentication)
      end

      it 'returns correct category for transaction actions' do
        expect(action.action_category).to eq(:transactions)
      end

      it 'returns :other for unknown actions' do
        unknown_action = create(:user_action, action: 'unknown_action', user: user, company: company)
        expect(unknown_action.action_category).to eq(:other)
      end
    end

    describe '#formatted_details' do
      let(:action_with_details) do
        create(:user_action,
          user: user,
          company: company,
          details: {
            'password' => 'secret',
            'token' => 'jwt',
            'amount' => 100,
            'reason' => 'test'
          }
        )
      end

      it 'excludes sensitive fields' do
        formatted = action_with_details.formatted_details
        expect(formatted).not_to have_key('password')
        expect(formatted).not_to have_key('token')
        expect(formatted['amount']).to eq(100)
        expect(formatted['reason']).to eq('test')
      end
    end

    describe '#action_summary' do
      it 'returns formatted action summary' do
        summary = action.action_summary
        expect(summary).to include(user.name)
        expect(summary).to include('void transaction')
        expect(summary).to include('transaction')
      end

      it 'includes resource ID when present' do
        action.update!(resource_id: '123')
        summary = action.action_summary
        expect(summary).to include('#123')
      end
    end
  end

  describe 'sensitive data handling' do
    it 'defines sensitive actions' do
      expect(UserAction::SENSITIVE_ACTIONS).to include(
        'void_transaction', 'override_price', 'delete_user', 'assign_role'
      )
    end

    it 'categorizes actions by type' do
      expect(UserAction::ACTION_TYPES[:authentication]).to include('login', 'logout')
      expect(UserAction::ACTION_TYPES[:transactions]).to include('void_transaction', 'override_price')
      expect(UserAction::ACTION_TYPES[:user_management]).to include('assign_role', 'remove_role')
    end
  end
end
