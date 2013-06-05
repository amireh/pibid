configure do
  allowed_origin = settings.cors['allowed_origin']||''
  allowed_origin = :any if allowed_origin.empty?

  # CORS
  set :protection, :except => [:http_origin]
  set :allow_methods, [ :get, :post, :put, :patch, :delete, :options ]
  set :allow_origin, allowed_origin
  set :allow_headers, ["*", "Content-Type", "Accept", "AUTHORIZATION", "Cache-Control", 'X-Requested-With']
  set :allow_credentials, true
  set :max_age, "1728000"
end