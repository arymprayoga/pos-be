class Api::V1::BaseController < ApplicationController
  # Skip CSRF protection for API requests
  skip_before_action :verify_authenticity_token

  # Set content type to JSON
  before_action :set_content_type

  # Ensure company context for multi-tenancy
  before_action :set_current_company

  protected

  def set_content_type
    response.headers["Content-Type"] = "application/json"
  end

  def set_current_company
    @current_company_id = request.headers["X-Company-ID"] || params[:company_id]

    if @current_company_id.blank?
      render json: { error: "Company ID is required" }, status: :bad_request
      nil
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
