AppName       = "Pibi"
AppURL        = "http://api.pibibot.com"
AppGithubURL  = "https://github.com/amireh/pibid"
AppIssueURL   = "#{AppGithubURL}/issues"

configure do |app|
  enable :cross_origin
  use Rack::Session::Cookie, :secret => settings.credentials['cookie']['secret']

  # load everything
  require 'app/models/transaction'

  [ 'lib', 'app/helpers', 'app/models', 'app/controllers' ].each { |d|
    Dir.glob("#{d}/**/*.rb").each { |f| require f }
  }

  require "config/initializers/datamapper"

  Rabl.register!

  set :views, File.join($ROOT, 'app', 'views')
  set :protection, :except => [:http_origin]

  # CORS
  set :allow_methods, [ :get, :post, :put, :patch, :delete, :options ]
  set :allow_origin, :any
  set :allow_headers, ["*", "Content-Type", "Accept", "AUTHORIZATION", "Cache-Control", 'X-Requested-With']
  set :allow_credentials, true
  set :max_age, "1728000"

  require "config/initializers/omniauth"
  require "config/initializers/#{settings.environment}"
end

# skip Pony in test mode
configure :development, :production do |app|
  require "config/initializers/pony"
end