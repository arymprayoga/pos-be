# Comprehensive security headers configuration for POS API system
Rails.application.config.force_ssl = !Rails.env.development?

Rails.application.config.middleware.use Rack::Deflater

# Custom security headers middleware class
class SecurityHeadersMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    # Content Security Policy - Strict for API, allowing admin interface
    if env["PATH_INFO"].start_with?("/api/")
      # Strict CSP for API endpoints
      headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none';"
    elsif env["PATH_INFO"].start_with?("/admin/")
      # Relaxed CSP for ActiveAdmin interface
      headers["Content-Security-Policy"] = [
        "default-src 'self'",
        "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data:",
        "font-src 'self'",
        "connect-src 'self'",
        "frame-ancestors 'none'"
      ].join("; ")
    end

    # Prevent clickjacking attacks
    headers["X-Frame-Options"] = "DENY"

    # Prevent MIME type confusion attacks
    headers["X-Content-Type-Options"] = "nosniff"

    # XSS Protection (legacy browsers)
    headers["X-XSS-Protection"] = "1; mode=block"

    # Referrer Policy - strict for privacy
    headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

    # Permissions Policy - restrict dangerous features
    headers["Permissions-Policy"] = [
      "geolocation=()",
      "microphone=()",
      "camera=()",
      "magnetometer=()",
      "gyroscope=()",
      "fullscreen=(self)",
      "payment=()"
    ].join(", ")

    # Strict Transport Security - HTTPS only in production
    if Rails.env.production?
      headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
    end

    # Cache Control for API responses
    if env["PATH_INFO"].start_with?("/api/")
      headers["Cache-Control"] = "no-cache, no-store, must-revalidate, private"
      headers["Pragma"] = "no-cache"
      headers["Expires"] = "0"
    end

    # Remove server information disclosure
    headers.delete("Server")
    headers.delete("X-Powered-By")

    [ status, headers, response ]
  end
end

# Add the security headers middleware
Rails.application.config.middleware.insert_before 0, SecurityHeadersMiddleware

# Additional security configurations
Rails.application.config.session_store :cookie_store,
  key: "_pos_be_session_#{Rails.env}",
  secure: Rails.env.production?,
  httponly: true,
  same_site: :strict

# Secure cookie configuration
Rails.application.config.force_ssl = Rails.env.production?

# Content type sniffing prevention
Rails.application.config.content_type_options_nosniff = true
