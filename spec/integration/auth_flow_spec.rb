require 'rails_helper'

RSpec.describe 'Authentication Flow Integration', type: :integration do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company, password: 'password123') }

  describe 'JWT Authentication Flow' do
    describe 'Login Process' do
      it 'authenticates user with valid credentials' do
        # Test direct service calls to avoid middleware issues
        expect(user.authenticate('password123')).to be_truthy

        # Test JWT token generation
        access_token = JwtService.generate_access_token(user, company)
        expect(access_token).to be_present

        # Test JWT token validation
        result = JwtService.decode_access_token(access_token)
        expect(result[:success]).to be true
        expect(result[:payload]['user_id']).to eq(user.id)
        expect(result[:payload]['company_id']).to eq(company.id)
      end

      it 'creates and validates refresh tokens' do
        refresh_result = JwtService.generate_refresh_token(user, company)

        expect(refresh_result[:token]).to be_present
        expect(refresh_result[:record]).to be_a(RefreshToken)
        expect(refresh_result[:record].user).to eq(user)
        expect(refresh_result[:record].company).to eq(company)

        # Test refresh token validation
        validation_result = JwtService.validate_refresh_token(refresh_result[:token])
        expect(validation_result[:success]).to be true
        expect(validation_result[:user]).to eq(user)
        expect(validation_result[:company]).to eq(company)
      end

      it 'revokes refresh tokens' do
        refresh_result = JwtService.generate_refresh_token(user, company)
        token = refresh_result[:token]

        expect(JwtService.revoke_refresh_token(token)).to be true
        expect(refresh_result[:record].reload.revoked?).to be true

        # Should fail validation after revocation
        validation_result = JwtService.validate_refresh_token(token)
        expect(validation_result[:success]).to be false
        expect(validation_result[:error]).to eq('Token revoked')
      end
    end

    describe 'Authorization Header Processing' do
      let(:request_double) { double('request') }
      let(:headers) { {} }

      before do
        allow(request_double).to receive(:headers).and_return(headers)
      end

      it 'extracts user from valid Bearer token' do
        access_token = JwtService.generate_access_token(user, company)
        headers['Authorization'] = "Bearer #{access_token}"

        result = JwtService.extract_user_from_token(request_double)

        expect(result[:success]).to be true
        expect(result[:user]).to eq(user)
        expect(result[:company]).to eq(company)
      end

      it 'rejects invalid authorization formats' do
        headers['Authorization'] = 'InvalidFormat'

        result = JwtService.extract_user_from_token(request_double)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid authorization format')
      end

      it 'rejects expired tokens' do
        expired_token = create_expired_token(user, company)
        headers['Authorization'] = "Bearer #{expired_token}"

        result = JwtService.extract_user_from_token(request_double)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Token expired')
      end
    end

    describe 'Multi-tenancy' do
      let(:other_company) { create(:company) }
      let(:other_user) { create(:user, company: other_company) }

      it 'prevents cross-company token access' do
        # Create token for user in company A
        access_token = JwtService.generate_access_token(user, company)

        # Decode and modify to reference company B
        payload = JWT.decode(access_token, Rails.application.credentials.secret_key_base, false).first
        payload['company_id'] = other_company.id

        # Create new token with modified payload
        tampered_token = JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')

        headers = { 'Authorization' => "Bearer #{tampered_token}" }
        request_double = double('request', headers: headers)

        result = JwtService.extract_user_from_token(request_double)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid user or company')
      end

      it 'isolates refresh tokens by company' do
        # Create tokens for both companies
        token1 = JwtService.generate_refresh_token(user, company)
        token2 = JwtService.generate_refresh_token(other_user, other_company)

        # Revoke all tokens for company 1
        JwtService.revoke_all_user_tokens(user, company)

        # Company 1 tokens should be revoked
        expect(token1[:record].reload.revoked?).to be true

        # Company 2 tokens should remain active
        expect(token2[:record].reload.revoked?).to be false
      end
    end

    describe 'Token Cleanup' do
      it 'cleans up expired and old revoked tokens' do
        # Create various token states
        valid_token = create(:refresh_token, user: user, company: company)
        expired_token = create(:refresh_token, user: user, company: company, expires_at: 2.days.ago)
        old_revoked_token = create(:refresh_token, user: user, company: company, revoked_at: 31.days.ago)
        recent_revoked_token = create(:refresh_token, user: user, company: company, revoked_at: 1.day.ago)

        expect { RefreshToken.cleanup_expired! }.to change { RefreshToken.count }.by(-2)

        expect(RefreshToken.exists?(valid_token.id)).to be true
        expect(RefreshToken.exists?(recent_revoked_token.id)).to be true
        expect(RefreshToken.exists?(expired_token.id)).to be false
        expect(RefreshToken.exists?(old_revoked_token.id)).to be false
      end
    end
  end

  private

  def create_expired_token(user, company)
    payload = {
      user_id: user.id,
      company_id: company.id,
      email: user.email,
      role: user.role,
      exp: 1.hour.ago.to_i,
      iat: 2.hours.ago.to_i
    }
    JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
  end
end
