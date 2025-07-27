# Enable rack-attack
class Rack::Attack
  # Redis store for rate limiting
  Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/2" },
    namespace: "pos_be_#{Rails.env}_rate_limit"
  )

  # Throttle all requests by IP (60rpm)
  throttle("req/ip", limit: 60, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  # Throttle API requests per company
  throttle("api/company", limit: 1000, period: 1.hour) do |req|
    if req.path.start_with?("/api/")
      company_id = req.env["HTTP_X_COMPANY_ID"] ||
                   (req.session && req.session[:company_id])
      company_id if company_id
    end
  end

  # Throttle login attempts by IP
  throttle("login/ip", limit: 5, period: 20.minutes) do |req|
    if req.path == "/admin/login" && req.post?
      req.ip
    end
  end

  # Throttle login attempts by email parameter
  throttle("login/email", limit: 5, period: 20.minutes) do |req|
    if req.path == "/admin/login" && req.post?
      req.params["admin_user"] && req.params["admin_user"]["email"]
    end
  end

  # Throttle sync endpoints more aggressively
  throttle("sync/company", limit: 100, period: 1.hour) do |req|
    if req.path.start_with?("/api/v1/sync/")
      company_id = req.env["HTTP_X_COMPANY_ID"] ||
                   (req.session && req.session[:company_id])
      company_id if company_id
    end
  end

  # Blocklist bad actors
  blocklist("block bad actors") do |req|
    # Block requests from known bad IPs
    Rack::Attack::Fail2Ban.filter("pentest-#{req.ip}", maxretry: 3, findtime: 10.minutes, bantime: 1.hour) do
      # Detect penetration testing patterns
      CGI.unescape(req.query_string) =~ %r{/etc/passwd} ||
      req.path.include?("/etc/passwd") ||
      req.path.include?("wp-admin") ||
      req.path.include?(".php")
    end
  end

  # Always allow requests from localhost in development
  safelist("allow from localhost") do |req|
    "127.0.0.1" == req.ip || "::1" == req.ip if Rails.env.development?
  end
end

# Configure throttled response
ActiveSupport::Notifications.subscribe("rack.attack") do |name, start, finish, request_id, payload|
  req = payload[:request]
  Rails.logger.warn "[Rack::Attack] #{req.env['rack.attack.match_type']} #{req.ip} #{req.request_method} #{req.fullpath}"
end
