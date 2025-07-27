class Api::V1::BaseController < ApplicationController
  include AuditLogging

  # Skip CSRF protection for API requests
  skip_before_action :verify_authenticity_token

  # Set content type to JSON
  before_action :set_content_type

  # Authenticate user with JWT
  before_action :authenticate_user!

  # Ensure company context for multi-tenancy
  before_action :set_current_company

  attr_reader :current_user, :current_company, :current_user_session

  protected

  def set_content_type
    response.headers["Content-Type"] = "application/json"
  end

  def authenticate_user!
    result = JwtService.extract_user_from_token(request)

    unless result[:success]
      render_error(result[:error], :unauthorized)
      return false
    end

    @current_user = result[:user]
    @current_company = result[:company]

    # Set context for multi-tenant models
    ApplicationRecord.current_company = @current_company
    Auditable.current_user = @current_user if defined?(Auditable)

    true
  end

  def set_current_company
    # Company is already set from JWT token in authenticate_user!
    # This method is kept for compatibility but the logic is now in authenticate_user!
    return if @current_company.present?

    # Fallback for controllers that skip authentication
    company_id = request.headers["X-Company-ID"] || params[:company_id]
    if company_id.present?
      @current_company = Company.find_by(id: company_id)
      ApplicationRecord.current_company = @current_company if @current_company
    end
  end

  def render_success(data = {}, message = "Success", status = :ok)
    render json: {
      success: true,
      message: message,
      data: data,
      timestamp: Time.current.iso8601
    }, status: status
  end

  def render_error(message = "An error occurred", status = :unprocessable_entity, errors = [])
    render json: {
      success: false,
      message: message,
      errors: errors,
      timestamp: Time.current.iso8601
    }, status: status
  end
end
