class Api::V1::AuthController < Api::V1::BaseController
  skip_before_action :authenticate_user!, only: [ :login, :refresh, :logout ]
  skip_before_action :set_current_company, only: [ :login, :refresh, :logout ]

  # POST /api/v1/auth/login
  def login
    company = Company.find_by(id: login_params[:company_id])
    return render_error("Company not found", :not_found) unless company

    user = User.where(company: company)
               .where(email: login_params[:email])
               .where(deleted_at: nil)
               .first

    unless user&.authenticate(login_params[:password])
      return render_error("Invalid email or password", :unauthorized)
    end

    unless user.active?
      return render_error("Account is inactive", :unauthorized)
    end

    # Generate device fingerprint
    device_fingerprint = JwtService.generate_device_fingerprint(request)

    # Generate tokens
    access_token = JwtService.generate_access_token(user, company)
    refresh_result = JwtService.generate_refresh_token(user, company, device_fingerprint)

    render_success({
      user: user_data(user),
      company: company_data(company),
      access_token: access_token,
      refresh_token: refresh_result[:token],
      expires_in: JwtService::ACCESS_TOKEN_EXPIRATION.to_i
    })
  end

  # POST /api/v1/auth/refresh
  def refresh
    refresh_token = refresh_params[:refresh_token]
    return render_error("Refresh token is required", :bad_request) unless refresh_token

    result = JwtService.validate_refresh_token(refresh_token)
    return render_error(result[:error], :unauthorized) unless result[:success]

    user = result[:user]
    company = result[:company]

    # Check if user is still active
    unless user.active?
      JwtService.revoke_refresh_token(refresh_token)
      return render_error("Account is inactive", :unauthorized)
    end

    # Generate new access token
    access_token = JwtService.generate_access_token(user, company)

    render_success({
      user: user_data(user),
      company: company_data(company),
      access_token: access_token,
      expires_in: JwtService::ACCESS_TOKEN_EXPIRATION.to_i
    })
  end

  # DELETE /api/v1/auth/logout
  def logout
    refresh_token = logout_params[:refresh_token]

    if refresh_token
      JwtService.revoke_refresh_token(refresh_token)
    end

    render_success({ message: "Logged out successfully" })
  end

  # DELETE /api/v1/auth/logout_all
  def logout_all
    JwtService.revoke_all_user_tokens(current_user, current_company)
    render_success({ message: "Logged out from all devices" })
  end

  private

  def login_params
    params.require(:auth).permit(:email, :password, :company_id)
  end

  def refresh_params
    params.require(:auth).permit(:refresh_token)
  end

  def logout_params
    params.permit(:refresh_token)
  end

  def user_data(user)
    {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      active: user.active?,
      created_at: user.created_at
    }
  end

  def company_data(company)
    {
      id: company.id,
      name: company.name,
      active: company.active?,
      created_at: company.created_at
    }
  end
end
