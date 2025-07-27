require 'rails_helper'

RSpec.describe UserSession, type: :model do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  describe 'validations' do
    subject { build(:user_session, company: company, user: user) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:session_token) }
    it { is_expected.to validate_presence_of(:device_fingerprint) }
    it { is_expected.to validate_presence_of(:ip_address) }
    it { is_expected.to validate_uniqueness_of(:session_token) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'scopes' do
    describe '.active' do
      it 'returns only active sessions' do
        active_session = create(:user_session, user: user, company: company)
        active_session.update!(expired_at: 8.hours.from_now, logged_out_at: nil)

        expired_session = create(:user_session, user: user, company: company)
        expired_session.update!(expired_at: 1.hour.ago, logged_out_at: nil)

        expect(UserSession.active).to include(active_session)
        expect(UserSession.active).not_to include(expired_session)
      end
    end

    describe '.expired' do
      it 'returns expired sessions' do
        active_session = create(:user_session, user: user, company: company)
        active_session.update!(expired_at: 8.hours.from_now, logged_out_at: nil)

        expired_session = create(:user_session, user: user, company: company)
        expired_session.update!(expired_at: 1.hour.ago, logged_out_at: nil)

        expect(UserSession.expired).to include(expired_session)
        expect(UserSession.expired).not_to include(active_session)
      end
    end

    describe '.for_user' do
      it 'returns sessions for specific user' do
        other_user = create(:user, company: company)
        user_session = create(:user_session, user: user, company: company)
        other_session = create(:user_session, user: other_user, company: company)

        user_sessions = UserSession.for_user(user)
        expect(user_sessions).to include(user_session)
        expect(user_sessions).not_to include(other_session)
      end
    end

    describe '.for_device' do
      it 'returns sessions for specific device' do
        device_fingerprint = 'shared_device_123'
        session1 = create(:user_session, user: user, company: company)
        session1.update!(device_fingerprint: device_fingerprint)

        session2 = create(:user_session, user: user, company: company)
        session2.update!(device_fingerprint: device_fingerprint)

        expect(UserSession.for_device(device_fingerprint)).to contain_exactly(session1, session2)
      end
    end
  end


  describe '.find_active_session' do
    it 'finds active session by token' do
      active_session = create(:user_session, user: user, company: company)
      active_session.update!(expired_at: 8.hours.from_now, logged_out_at: nil)

      found_session = UserSession.find_active_session(active_session.session_token)
      expect(found_session).to eq(active_session)
    end

    it 'returns nil for expired session' do
      expired_session = create(:user_session, user: user, company: company)
      expired_session.update!(expired_at: 1.hour.ago, logged_out_at: nil)

      found_session = UserSession.find_active_session(expired_session.session_token)
      expect(found_session).to be_nil
    end

    it 'returns nil for non-existent token' do
      found_session = UserSession.find_active_session('invalid_token')
      expect(found_session).to be_nil
    end
  end

  describe '.cleanup_expired_sessions' do
    it 'removes expired and old sessions' do
      active_session = create(:user_session, expired_at: 8.hours.from_now)
      expired_session = create(:user_session, expired_at: 1.hour.ago)
      old_session = create(:user_session, created_at: 31.days.ago)

      expect {
        UserSession.cleanup_expired_sessions
      }.to change { UserSession.count }.by_at_least(-1)

      expect(UserSession.exists?(active_session.id)).to be true
    end
  end

  describe '.revoke_all_for_user' do
    it 'revokes all sessions for specific user' do
      session1 = create(:user_session, user: user, logged_out_at: nil)
      session2 = create(:user_session, user: user, logged_out_at: nil)
      other_user_session = create(:user_session, logged_out_at: nil)

      UserSession.revoke_all_for_user(user)

      session1.reload
      session2.reload
      other_user_session.reload

      expect(session1.logged_out_at).to be_present
      expect(session2.logged_out_at).to be_present
      expect(other_user_session.logged_out_at).to be_nil
    end
  end

  describe 'instance methods' do
    let(:session) { create(:user_session, user: user, company: company, expired_at: 8.hours.from_now, logged_out_at: nil) }

    describe '#active?' do
      it 'returns true for active session' do
        expect(session).to be_active
      end

      it 'returns false for expired session' do
        session.update!(expired_at: 1.hour.ago)
        expect(session).not_to be_active
      end

      it 'returns false for logged out session' do
        session.update!(logged_out_at: 1.hour.ago)
        expect(session).not_to be_active
      end
    end

    describe '#expire!' do
      it 'sets expired_at to current time' do
        session.expire!
        expect(session.expired_at).to be_within(1.second).of(Time.current)
      end
    end

    describe '#logout!' do
      it 'sets both logged_out_at and expired_at' do
        session.logout!
        expect(session.logged_out_at).to be_within(1.second).of(Time.current)
        expect(session.expired_at).to be_within(1.second).of(Time.current)
      end
    end

    describe '#session_info' do
      it 'returns session information hash' do
        info = session.session_info

        expect(info).to include(:id, :device_fingerprint, :ip_address, :active)
        expect(info[:active]).to be true
      end
    end
  end
end
