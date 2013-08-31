configure do
  enable :cross_origin

  unless settings.respond_to?(:expose_headers)
    set :expose_headers, nil
  end

  allowed_origin = settings.cors['allowed_origin']||''
  allowed_origin = :any if allowed_origin.empty?

  # CORS
  set :protection, :except => [ :http_origin ]
  set :allow_methods, [ :get, :post, :put, :patch, :delete, :options ]
  set :allow_origin, allowed_origin
  set :allow_headers, ["*", "Content-Type", "Accept", "AUTHORIZATION", "Cache-Control", 'X-Requested-With']
  set :allow_credentials, true
  set :max_age, "1728000"
end

options '*' do
  response.headers['Access-Control-Max-Age'] = '1728000'

  halt 200
end
