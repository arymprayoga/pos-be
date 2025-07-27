require 'rails_helper'

RSpec.describe RefreshToken, type: :model do
  subject { build(:refresh_token) }

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:company) }
  end

  describe 'validations' do
    it { should validate_presence_of(:token_hash) }
    it { should validate_presence_of(:expires_at) }
    it { should validate_presence_of(:user_id) }
    it { should validate_presence_of(:company_id) }
    it { should validate_uniqueness_of(:token_hash) }
  end

  describe 'scopes' do
    let!(:active_token) { create(:refresh_token) }
    let!(:expired_token) { create(:refresh_token, :expired) }
    let!(:revoked_token) { create(:refresh_token, :revoked) }

    describe '.active' do
      it 'returns only non-revoked tokens' do
        expect(RefreshToken.active).to include(active_token, expired_token)
        expect(RefreshToken.active).not_to include(revoked_token)
      end
    end

    describe '.expired' do
      it 'returns only expired tokens' do
        expect(RefreshToken.expired).to include(expired_token)
        expect(RefreshToken.expired).not_to include(active_token, revoked_token)
      end
    end

    describe '.valid' do
      it 'returns only valid (active and not expired) tokens' do
        expect(RefreshToken.valid).to include(active_token)
        expect(RefreshToken.valid).not_to include(expired_token, revoked_token)
      end
    end
  end

  describe '#expired?' do
    context 'when token is expired' do
      let(:token) { create(:refresh_token, :expired) }

      it 'returns true' do
        expect(token.expired?).to be true
      end
    end

    context 'when token is not expired' do
      let(:token) { create(:refresh_token) }

      it 'returns false' do
        expect(token.expired?).to be false
      end
    end
  end

  describe '#revoked?' do
    context 'when token is revoked' do
      let(:token) { create(:refresh_token, :revoked) }

      it 'returns true' do
        expect(token.revoked?).to be true
      end
    end

    context 'when token is not revoked' do
      let(:token) { create(:refresh_token) }

      it 'returns false' do
        expect(token.revoked?).to be false
      end
    end
  end

  describe '#token_valid?' do
    context 'when token is valid (not expired and not revoked)' do
      let(:token) { create(:refresh_token) }

      it 'returns true' do
        expect(token.token_valid?).to be true
      end
    end

    context 'when token is expired' do
      let(:token) { create(:refresh_token, :expired) }

      it 'returns false' do
        expect(token.token_valid?).to be false
      end
    end

    context 'when token is revoked' do
      let(:token) { create(:refresh_token, :revoked) }

      it 'returns false' do
        expect(token.token_valid?).to be false
      end
    end

    context 'when token is both expired and revoked' do
      let(:token) { create(:refresh_token, :expired_and_revoked) }

      it 'returns false' do
        expect(token.token_valid?).to be false
      end
    end
  end

  describe '#revoke!' do
    let(:token) { create(:refresh_token) }

    it 'sets revoked_at timestamp' do
      expect { token.revoke! }.to change { token.revoked_at }.from(nil)
      expect(token.revoked_at).to be_within(1.second).of(Time.current)
    end

    it 'makes the token revoked' do
      expect { token.revoke! }.to change { token.revoked? }.from(false).to(true)
    end
  end

  describe '.cleanup_expired!' do
    let!(:valid_token) { create(:refresh_token) }
    let!(:expired_token) { create(:refresh_token, expires_at: 2.days.ago) }
    let!(:old_revoked_token) { create(:refresh_token, revoked_at: 31.days.ago) }
    let!(:recent_revoked_token) { create(:refresh_token, revoked_at: 1.day.ago) }

    it 'deletes expired tokens and old revoked tokens' do
      expect { RefreshToken.cleanup_expired! }.to change { RefreshToken.count }.by(-2)

      expect(RefreshToken.exists?(valid_token.id)).to be true
      expect(RefreshToken.exists?(recent_revoked_token.id)).to be true
      expect(RefreshToken.exists?(expired_token.id)).to be false
      expect(RefreshToken.exists?(old_revoked_token.id)).to be false
    end
  end

  describe 'multi-tenancy' do
    let(:company1) { create(:company) }
    let(:company2) { create(:company) }
    let(:user1) { create(:user, company: company1) }
    let(:user2) { create(:user, company: company2) }
    let!(:token1) { create(:refresh_token, user: user1, company: company1) }
    let!(:token2) { create(:refresh_token, user: user2, company: company2) }

    it 'includes Auditable concern' do
      expect(RefreshToken.ancestors).to include(Auditable)
    end

    it 'belongs to the correct company' do
      expect(token1.company).to eq(company1)
      expect(token2.company).to eq(company2)
    end
  end
end
