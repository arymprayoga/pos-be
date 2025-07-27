module ApiHelpers
  def json_response
    JSON.parse(response.body) if response.body.present?
  end

  def auth_headers_for(user, company)
    token = JwtService.generate_access_token(user, company)
    { 'Authorization' => "Bearer #{token}" }
  end

  def api_headers
    { 'Content-Type' => 'application/json' }
  end

  def post_json(path, params = {})
    post path, params: params.to_json, headers: api_headers
  end

  def delete_json(path, params = {})
    delete path, params: params.to_json, headers: api_headers
  end

  def delete_with_auth(path, user, company, params = {})
    headers = api_headers.merge(auth_headers_for(user, company))
    delete path, params: params.to_json, headers: headers
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
