class JwtService
  # Token expiration times
  ACCESS_TOKEN_EXPIRATION = 15.minutes
  REFRESH_TOKEN_EXPIRATION = 30.days

  class << self
    # Generate access token (15 minutes)
    def generate_access_token(user, company)
      payload = {
        user_id: user.id,
        company_id: company.id,
        email: user.email,
        role: user.role,
        exp: ACCESS_TOKEN_EXPIRATION.from_now.to_i,
        iat: Time.current.to_i
      }

      JWT.encode(payload, secret_key, "HS256")
    end

    # Generate refresh token and store in database
    def generate_refresh_token(user, company, device_fingerprint = nil)
      # Generate random token
      token = SecureRandom.hex(32)
      token_hash = Digest::SHA256.hexdigest(token)

      # Store in database
      refresh_token = RefreshToken.create!(
        user: user,
        company: company,
        token_hash: token_hash,
        device_fingerprint: device_fingerprint,
        expires_at: REFRESH_TOKEN_EXPIRATION.from_now
      )

      { token: token, record: refresh_token }
    end

    # Validate and decode access token
    def decode_access_token(token)
      begin
        decoded = JWT.decode(token, secret_key, true, { algorithm: "HS256" })
        payload = decoded.first

        { success: true, payload: payload }
      rescue JWT::ExpiredSignature => e
        { success: false, error: "Token expired" }
      rescue JWT::DecodeError => e
        { success: false, error: "Invalid token" }
      rescue => e
        { success: false, error: "Token validation failed" }
      end
    end

    # Validate refresh token
    def validate_refresh_token(token)
      token_hash = Digest::SHA256.hexdigest(token)

      refresh_token = RefreshToken.includes(:user, :company)
                                  .find_by(token_hash: token_hash)

      return { success: false, error: "Invalid refresh token" } unless refresh_token
      return { success: false, error: "Token expired" } if refresh_token.expired?
      return { success: false, error: "Token revoked" } if refresh_token.revoked?

      {
        success: true,
        refresh_token: refresh_token,
        user: refresh_token.user,
        company: refresh_token.company
      }
    end

    # Revoke refresh token
    def revoke_refresh_token(token)
      token_hash = Digest::SHA256.hexdigest(token)
      refresh_token = RefreshToken.find_by(token_hash: token_hash)

      return false unless refresh_token

      refresh_token.revoke!
      true
    end

    # Revoke all refresh tokens for a user
    def revoke_all_user_tokens(user, company)
      RefreshToken.where(user: user, company: company, revoked_at: nil)
                  .update_all(revoked_at: Time.current)
    end

    # Clean up expired and revoked tokens
    def cleanup_tokens!
      RefreshToken.cleanup_expired!
    end

    # Generate device fingerprint
    def generate_device_fingerprint(request)
      components = [
        request.user_agent,
        request.remote_ip,
        request.headers["Accept-Language"],
        request.headers["Accept-Encoding"]
      ].compact.join("|")

      Digest::SHA256.hexdigest(components)
    end

    # Extract user and company from request
    def extract_user_from_token(request)
      auth_header = request.headers["Authorization"]
      return { success: false, error: "No authorization header" } unless auth_header

      # Check for Bearer token format
      parts = auth_header.split(" ")
      return { success: false, error: "Invalid authorization format" } unless parts.length == 2 && parts.first.downcase == "bearer"

      token = parts.last

      result = decode_access_token(token)
      return result unless result[:success]

      payload = result[:payload]
      user = User.includes(:company).find_by(id: payload["user_id"])
      company = Company.find_by(id: payload["company_id"])

      if user && company && user.company_id == company.id
        { success: true, user: user, company: company, payload: payload }
      else
        { success: false, error: "Invalid user or company" }
      end
    end

    private

    def secret_key
      Rails.application.credentials.secret_key_base
    end
  end
end
