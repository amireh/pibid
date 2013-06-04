AppName       = "Pibi"
AppURL        = "http://api.pibiapp.com"
AppGithubURL  = "https://github.com/amireh/pibid"
AppIssueURL   = "#{AppGithubURL}/issues"

configure do |app|
  enable :cross_origin
  include Sinatra::SSE

  # use Rack::Session::Cookie,
  #   :domain => '.pibi.kodoware.com',
  #   :secret => settings.credentials['cookie']['secret']

  require 'app/models/transaction'
  require 'lib/pibi'

  Pibi::Preferences.init

  [ 'lib', 'app/helpers', 'app/models', 'app/controllers' ].each { |d|
    Dir.glob("#{d}/**/*.rb").each { |f| require f }
  }

  # Grant access to default preferences just like any :preferencable model
  #
  # @example
  #   DefaultPreferences.p['foo']['bar'] = 123
  #   DefaultPreferences.p['foo.bar']           # => 123
  #
  DefaultPreferences = User.new
  DefaultPreferences.__override_preferences(Pibi::Preferences.defaults)

  User.default_categories = settings.user['default_categories']

  # puts "User categories: #{User.default_categories}"

  set :views, File.join($ROOT, 'app', 'views')
  set :protection, :except => [:http_origin]
  set connections: {}

  # CORS
  set :allow_methods, [ :get, :post, :put, :patch, :delete, :options ]
  set :allow_origin, ( settings.allowed_origin || '' ).empty? ? :any : settings.allowed_origin
  set :allow_headers, ["*", "Content-Type", "Accept", "AUTHORIZATION", "Cache-Control", 'X-Requested-With']
  set :allow_credentials, true
  set :max_age, "1728000"

  require "config/initializers/datamapper"
  require "config/initializers/rabl"
  require "config/initializers/omniauth"
  require "config/initializers/comlink"
  require "config/initializers/#{settings.environment}"
end