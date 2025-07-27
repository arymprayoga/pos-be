require 'rails_helper'

RSpec.describe JwtService, type: :service do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:device_fingerprint) { 'test_device_fingerprint' }

  describe '.generate_access_token' do
    let(:token) { JwtService.generate_access_token(user, company) }

    it 'generates a valid JWT token' do
      expect(token).to be_present
      expect(token.split('.').length).to eq(3) # JWT has 3 parts
    end

    it 'includes correct payload data' do
      decoded = JWT.decode(token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' })
      payload = decoded.first

      expect(payload['user_id']).to eq(user.id)
      expect(payload['company_id']).to eq(company.id)
      expect(payload['email']).to eq(user.email)
      expect(payload['role']).to eq(user.role)
      expect(payload['exp']).to be > Time.current.to_i
      expect(payload['iat']).to be <= Time.current.to_i
    end

    it 'sets expiration to 15 minutes from now' do
      decoded = JWT.decode(token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' })
      payload = decoded.first
      expected_exp = 15.minutes.from_now.to_i

      expect(payload['exp']).to be_within(5).of(expected_exp)
    end
  end

  describe '.generate_refresh_token' do
    let(:result) { JwtService.generate_refresh_token(user, company, device_fingerprint) }

    it 'returns token and record' do
      expect(result).to have_key(:token)
      expect(result).to have_key(:record)
    end

    it 'creates a RefreshToken record' do
      expect { result }.to change { RefreshToken.count }.by(1)
    end

    it 'stores hashed token in database' do
      token_hash = Digest::SHA256.hexdigest(result[:token])
      expect(result[:record].token_hash).to eq(token_hash)
    end

    it 'sets correct attributes' do
      record = result[:record]

      expect(record.user).to eq(user)
      expect(record.company).to eq(company)
      expect(record.device_fingerprint).to eq(device_fingerprint)
      expect(record.expires_at).to be_within(1.minute).of(30.days.from_now)
    end
  end

  describe '.decode_access_token' do
    context 'with valid token' do
      let(:token) { JwtService.generate_access_token(user, company) }
      let(:result) { JwtService.decode_access_token(token) }

      it 'successfully decodes the token' do
        expect(result[:success]).to be true
        expect(result[:payload]).to be_present
      end

      it 'returns correct payload data' do
        payload = result[:payload]

        expect(payload['user_id']).to eq(user.id)
        expect(payload['company_id']).to eq(company.id)
        expect(payload['email']).to eq(user.email)
        expect(payload['role']).to eq(user.role)
      end
    end

    context 'with expired token' do
      let(:expired_token) do
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

      it 'returns error for expired token' do
        result = JwtService.decode_access_token(expired_token)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Token expired')
      end
    end

    context 'with invalid token' do
      it 'returns error for malformed token' do
        result = JwtService.decode_access_token('invalid.token.here')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid token')
      end
    end

    context 'with tampered token' do
      let(:tampered_token) { JwtService.generate_access_token(user, company) + 'tampered' }

      it 'returns error for tampered token' do
        result = JwtService.decode_access_token(tampered_token)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid token')
      end
    end
  end

  describe '.validate_refresh_token' do
    let(:refresh_result) { JwtService.generate_refresh_token(user, company, device_fingerprint) }
    let(:token) { refresh_result[:token] }

    context 'with valid refresh token' do
      it 'returns success with user and company data' do
        result = JwtService.validate_refresh_token(token)

        expect(result[:success]).to be true
        expect(result[:user]).to eq(user)
        expect(result[:company]).to eq(company)
        expect(result[:refresh_token]).to eq(refresh_result[:record])
      end
    end

    context 'with invalid token hash' do
      it 'returns error for non-existent token' do
        result = JwtService.validate_refresh_token('nonexistent_token')

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid refresh token')
      end
    end

    context 'with expired refresh token' do
      before do
        refresh_result[:record].update!(expires_at: 1.day.ago)
      end

      it 'returns error for expired token' do
        result = JwtService.validate_refresh_token(token)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Token expired')
      end
    end

    context 'with revoked refresh token' do
      before do
        refresh_result[:record].revoke!
      end

      it 'returns error for revoked token' do
        result = JwtService.validate_refresh_token(token)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Token revoked')
      end
    end
  end

  describe '.revoke_refresh_token' do
    let(:refresh_result) { JwtService.generate_refresh_token(user, company, device_fingerprint) }
    let(:token) { refresh_result[:token] }

    context 'with valid token' do
      it 'revokes the token' do
        expect(JwtService.revoke_refresh_token(token)).to be true
        expect(refresh_result[:record].reload.revoked?).to be true
      end
    end

    context 'with invalid token' do
      it 'returns false for non-existent token' do
        expect(JwtService.revoke_refresh_token('nonexistent_token')).to be false
      end
    end
  end

  describe '.revoke_all_user_tokens' do
    let!(:token1) { create(:refresh_token, user: user, company: company) }
    let!(:token2) { create(:refresh_token, user: user, company: company) }
    let!(:other_user_token) { create(:refresh_token, company: company) }

    it 'revokes all tokens for the specific user and company' do
      JwtService.revoke_all_user_tokens(user, company)

      expect(token1.reload.revoked?).to be true
      expect(token2.reload.revoked?).to be true
      expect(other_user_token.reload.revoked?).to be false
    end
  end

  describe '.cleanup_tokens!' do
    let!(:valid_token) { create(:refresh_token) }
    let!(:expired_token) { create(:refresh_token, expires_at: 2.days.ago) }
    let!(:old_revoked_token) { create(:refresh_token, revoked_at: 31.days.ago) }

    it 'delegates to RefreshToken.cleanup_expired!' do
      expect(RefreshToken).to receive(:cleanup_expired!)
      JwtService.cleanup_tokens!
    end
  end

  describe '.generate_device_fingerprint' do
    let(:request) { double('request') }

    before do
      allow(request).to receive(:user_agent).and_return('Mozilla/5.0')
      allow(request).to receive(:remote_ip).and_return('192.168.1.1')
      allow(request).to receive(:headers).and_return({
        'Accept-Language' => 'en-US,en;q=0.9',
        'Accept-Encoding' => 'gzip, deflate'
      })
    end

    it 'generates consistent fingerprint for same request' do
      fingerprint1 = JwtService.generate_device_fingerprint(request)
      fingerprint2 = JwtService.generate_device_fingerprint(request)

      expect(fingerprint1).to eq(fingerprint2)
      expect(fingerprint1).to be_present
    end

    it 'generates different fingerprints for different requests' do
      allow(request).to receive(:user_agent).and_return('Different Agent')

      fingerprint1 = JwtService.generate_device_fingerprint(request)
      fingerprint2 = JwtService.generate_device_fingerprint(request)

      expect(fingerprint1).to eq(fingerprint2) # Same modified request

      # Reset and try with original
      allow(request).to receive(:user_agent).and_return('Mozilla/5.0')
      fingerprint3 = JwtService.generate_device_fingerprint(request)

      expect(fingerprint1).not_to eq(fingerprint3)
    end
  end

  describe '.extract_user_from_token' do
    let(:request) { double('request') }
    let(:headers) { {} }

    before do
      allow(request).to receive(:headers).and_return(headers)
    end

    context 'with valid authorization header and token' do
      let(:token) { JwtService.generate_access_token(user, company) }

      before do
        headers['Authorization'] = "Bearer #{token}"
      end

      it 'returns user and company data' do
        result = JwtService.extract_user_from_token(request)

        expect(result[:success]).to be true
        expect(result[:user]).to eq(user)
        expect(result[:company]).to eq(company)
        expect(result[:payload]).to be_present
      end
    end

    context 'without authorization header' do
      it 'returns error' do
        result = JwtService.extract_user_from_token(request)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('No authorization header')
      end
    end

    context 'with invalid authorization format' do
      before do
        headers['Authorization'] = 'InvalidFormat'
      end

      it 'returns error' do
        result = JwtService.extract_user_from_token(request)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid authorization format')
      end
    end

    context 'with expired token' do
      let(:expired_token) do
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

      before do
        headers['Authorization'] = "Bearer #{expired_token}"
      end

      it 'returns error for expired token' do
        result = JwtService.extract_user_from_token(request)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Token expired')
      end
    end

    context 'with non-existent user' do
      let(:token) do
        payload = {
          user_id: 'non-existent-id',
          company_id: company.id,
          email: 'nonexistent@example.com',
          role: 'manager',
          exp: 15.minutes.from_now.to_i,
          iat: Time.current.to_i
        }
        JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
      end

      before do
        headers['Authorization'] = "Bearer #{token}"
      end

      it 'returns error for invalid user' do
        result = JwtService.extract_user_from_token(request)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid user or company')
      end
    end

    context 'with user not belonging to company' do
      let(:other_company) { create(:company) }
      let(:token) do
        payload = {
          user_id: user.id,
          company_id: other_company.id,
          email: user.email,
          role: user.role,
          exp: 15.minutes.from_now.to_i,
          iat: Time.current.to_i
        }
        JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
      end

      before do
        headers['Authorization'] = "Bearer #{token}"
      end

      it 'returns error for mismatched company' do
        result = JwtService.extract_user_from_token(request)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid user or company')
      end
    end
  end
end
