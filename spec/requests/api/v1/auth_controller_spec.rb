require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company, password: 'password123') }
  let(:headers) { { 'Content-Type' => 'application/json' } }

  describe 'POST /api/v1/auth/login' do
    let(:login_url) { '/api/v1/auth/login' }
    let(:valid_params) do
      {
        auth: {
          email: user.email,
          password: 'password123',
          company_id: company.id
        }
      }
    end

    context 'with valid credentials' do
      it 'returns success with tokens and user data' do
        post login_url, params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['data']).to include(
          'user', 'company', 'access_token', 'refresh_token', 'expires_in'
        )

        # Check user data
        user_data = json['data']['user']
        expect(user_data['id']).to eq(user.id)
        expect(user_data['email']).to eq(user.email)
        expect(user_data['role']).to eq(user.role)
        expect(user_data['active']).to be true

        # Check company data
        company_data = json['data']['company']
        expect(company_data['id']).to eq(company.id)
        expect(company_data['name']).to eq(company.name)

        # Check tokens
        expect(json['data']['access_token']).to be_present
        expect(json['data']['refresh_token']).to be_present
        expect(json['data']['expires_in']).to eq(900) # 15 minutes
      end

      it 'creates a refresh token in database' do
        expect {
          post login_url, params: valid_params.to_json, headers: headers
        }.to change { RefreshToken.count }.by(1)

        refresh_token = RefreshToken.last
        expect(refresh_token.user).to eq(user)
        expect(refresh_token.company).to eq(company)
        expect(refresh_token.device_fingerprint).to be_present
      end

      it 'generates valid JWT access token' do
        post login_url, params: valid_params.to_json, headers: headers

        json = JSON.parse(response.body)
        access_token = json['data']['access_token']

        decoded = JWT.decode(access_token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' })
        payload = decoded.first

        expect(payload['user_id']).to eq(user.id)
        expect(payload['company_id']).to eq(company.id)
        expect(payload['email']).to eq(user.email)
        expect(payload['role']).to eq(user.role)
      end
    end

    context 'with invalid company_id' do
      let(:invalid_params) do
        valid_params.merge(auth: valid_params[:auth].merge(company_id: 'invalid-id'))
      end

      it 'returns not found error' do
        post login_url, params: invalid_params.to_json, headers: headers

        expect(response).to have_http_status(:not_found)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Company not found')
      end
    end

    context 'with invalid email' do
      let(:invalid_params) do
        valid_params.merge(auth: valid_params[:auth].merge(email: 'wrong@email.com'))
      end

      it 'returns unauthorized error' do
        post login_url, params: invalid_params.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Invalid email or password')
      end
    end

    context 'with invalid password' do
      let(:invalid_params) do
        valid_params.merge(auth: valid_params[:auth].merge(password: 'wrongpassword'))
      end

      it 'returns unauthorized error' do
        post login_url, params: invalid_params.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Invalid email or password')
      end
    end

    context 'with inactive user' do
      before do
        user.update!(active: false)
      end

      it 'returns unauthorized error' do
        post login_url, params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Account is inactive')
      end
    end

    context 'with deleted user' do
      before do
        user.update!(deleted_at: Time.current)
      end

      it 'returns unauthorized error' do
        post login_url, params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Invalid email or password')
      end
    end

    context 'with missing parameters' do
      it 'returns error for missing auth parameters' do
        post login_url, params: {}.to_json, headers: headers

        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe 'POST /api/v1/auth/refresh' do
    let(:refresh_url) { '/api/v1/auth/refresh' }
    let(:refresh_result) { JwtService.generate_refresh_token(user, company) }
    let(:refresh_token) { refresh_result[:token] }
    let(:valid_params) do
      {
        auth: {
          refresh_token: refresh_token
        }
      }
    end

    context 'with valid refresh token' do
      it 'returns new access token' do
        post refresh_url, params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['data']).to include('user', 'company', 'access_token', 'expires_in')
        expect(json['data']['access_token']).to be_present
        expect(json['data']['expires_in']).to eq(900)
      end

      it 'returns user and company data' do
        post refresh_url, params: valid_params.to_json, headers: headers

        json = JSON.parse(response.body)
        user_data = json['data']['user']
        company_data = json['data']['company']

        expect(user_data['id']).to eq(user.id)
        expect(user_data['email']).to eq(user.email)
        expect(company_data['id']).to eq(company.id)
        expect(company_data['name']).to eq(company.name)
      end

      it 'generates valid new access token' do
        post refresh_url, params: valid_params.to_json, headers: headers

        json = JSON.parse(response.body)
        access_token = json['data']['access_token']

        decoded = JWT.decode(access_token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' })
        payload = decoded.first

        expect(payload['user_id']).to eq(user.id)
        expect(payload['company_id']).to eq(company.id)
      end
    end

    context 'with invalid refresh token' do
      let(:invalid_params) do
        { auth: { refresh_token: 'invalid_token' } }
      end

      it 'returns unauthorized error' do
        post refresh_url, params: invalid_params.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Invalid refresh token')
      end
    end

    context 'with expired refresh token' do
      before do
        refresh_result[:record].update!(expires_at: 1.day.ago)
      end

      it 'returns unauthorized error' do
        post refresh_url, params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Token expired')
      end
    end

    context 'with revoked refresh token' do
      before do
        refresh_result[:record].revoke!
      end

      it 'returns unauthorized error' do
        post refresh_url, params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Token revoked')
      end
    end

    context 'with inactive user' do
      before do
        user.update!(active: false)
      end

      it 'returns unauthorized error and revokes token' do
        post refresh_url, params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Account is inactive')

        expect(refresh_result[:record].reload.revoked?).to be true
      end
    end

    context 'with missing refresh token' do
      it 'returns bad request error' do
        post refresh_url, params: { auth: {} }.to_json, headers: headers

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Refresh token is required')
      end
    end
  end

  describe 'DELETE /api/v1/auth/logout' do
    let(:logout_url) { '/api/v1/auth/logout' }
    let(:refresh_result) { JwtService.generate_refresh_token(user, company) }
    let(:refresh_token) { refresh_result[:token] }

    context 'with valid refresh token' do
      it 'successfully logs out and revokes token' do
        delete logout_url, params: { refresh_token: refresh_token }.to_json, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['data']['message']).to eq('Logged out successfully')

        expect(refresh_result[:record].reload.revoked?).to be true
      end
    end

    context 'without refresh token' do
      it 'still returns success' do
        delete logout_url, params: {}.to_json, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['data']['message']).to eq('Logged out successfully')
      end
    end

    context 'with invalid refresh token' do
      it 'still returns success (graceful handling)' do
        delete logout_url, params: { refresh_token: 'invalid_token' }.to_json, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['data']['message']).to eq('Logged out successfully')
      end
    end
  end

  describe 'DELETE /api/v1/auth/logout_all' do
    let(:logout_all_url) { '/api/v1/auth/logout_all' }
    let(:access_token) { JwtService.generate_access_token(user, company) }
    let(:auth_headers) { headers.merge('Authorization' => "Bearer #{access_token}") }

    before do
      # Create multiple refresh tokens for the user
      create_list(:refresh_token, 3, user: user, company: company)
    end

    context 'with valid authentication' do
      it 'revokes all user tokens' do
        expect {
          delete logout_all_url, headers: auth_headers
        }.to change { RefreshToken.where(user: user, company: company, revoked_at: nil).count }.to(0)

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['data']['message']).to eq('Logged out from all devices')
      end

      it 'does not affect other users tokens' do
        other_user = create(:user, company: company)
        other_token = create(:refresh_token, user: other_user, company: company)

        delete logout_all_url, headers: auth_headers

        expect(other_token.reload.revoked?).to be false
      end
    end

    context 'without authentication' do
      it 'returns unauthorized error' do
        delete logout_all_url, headers: headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('No authorization header')
      end
    end

    context 'with expired access token' do
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
      let(:expired_auth_headers) { headers.merge('Authorization' => "Bearer #{expired_token}") }

      it 'returns unauthorized error' do
        delete logout_all_url, headers: expired_auth_headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Token expired')
      end
    end
  end

  describe 'Authentication middleware integration' do
    let(:access_token) { JwtService.generate_access_token(user, company) }
    let(:auth_headers) { headers.merge('Authorization' => "Bearer #{access_token}") }

    context 'with valid access token' do
      it 'allows access to protected endpoints' do
        delete '/api/v1/auth/logout_all', headers: auth_headers

        expect(response).to have_http_status(:ok)
      end

      it 'sets current_user and current_company' do
        # This is tested indirectly through the logout_all functionality
        # which uses current_user and current_company
        user_tokens_count = RefreshToken.where(user: user, company: company).count
        expect(user_tokens_count).to be > 0

        delete '/api/v1/auth/logout_all', headers: auth_headers

        json = JSON.parse(response.body)
        expect(json['success']).to be true
      end
    end

    context 'without authorization header' do
      it 'rejects access to protected endpoints' do
        delete '/api/v1/auth/logout_all', headers: headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('No authorization header')
      end
    end

    context 'with malformed authorization header' do
      let(:malformed_headers) { headers.merge('Authorization' => 'InvalidFormat') }

      it 'rejects access to protected endpoints' do
        delete '/api/v1/auth/logout_all', headers: malformed_headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Invalid authorization format')
      end
    end
  end

  describe 'Rate limiting' do
    let(:login_url) { '/api/v1/auth/login' }

    it 'allows normal login requests' do
      valid_params = {
        auth: {
          email: user.email,
          password: 'password123',
          company_id: company.id
        }
      }

      post login_url, params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:ok)
    end

    # Note: Full rate limiting tests would require more setup
    # This is a basic smoke test to ensure rate limiting doesn't break normal flow
  end
end
