# Configure Rails to use UUIDs as primary keys
Rails.application.configure do
  config.generators do |g|
    g.orm :active_record, primary_key_type: :uuid
  end
end
