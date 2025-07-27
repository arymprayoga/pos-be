# Use Redis for session storage with Rails 8 built-in support
Rails.application.config.session_store :cache_store,
  key: "_pos_be_session_#{Rails.env}",
  expire_after: 30.days,
  secure: Rails.env.production?,
  same_site: :lax
