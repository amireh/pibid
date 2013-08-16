AppName       = "Pibi"
AppURL        = "http://api.pibiapp.com"
AppGithubURL  = "https://github.com/amireh/pibid"
AppIssueURL   = "#{AppGithubURL}/issues"

configure do |app|
  require 'app/models/transaction'

  [ 'lib', 'app/helpers', 'app/models', 'app/controllers' ].each { |d|
    Dir.glob("#{d}/**/*.rb").each { |f| require f }
  }

  User.default_categories = settings.user['default_categories']

  # puts "User categories: #{User.default_categories}"

  set :views, File.join($ROOT, 'app', 'views')

  require "config/initializers/datamapper"
  require "config/initializers/rabl"
  require "config/initializers/omniauth"
  require "config/initializers/#{settings.environment}"
end

configure :production, :development do
  require "config/initializers/cors"
  require "config/initializers/comlink"
end