# Use Redis for session storage
Rails.application.config.session_store :redis_store,
  servers: [ ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } ],
  expire_after: 30.days,
  key: "_pos_be_session_#{Rails.env}",
  threadsafe: true,
  secure: Rails.env.production?,
  same_site: :lax
