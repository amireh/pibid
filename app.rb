# encoding: UTF-8

$ROOT ||= File.dirname(__FILE__)
$LOAD_PATH << $ROOT

require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)


# ----
# Validating that configuration files exist and are readable...
config_files = [ 'application', 'database' ]
config_files << 'credentials' unless settings.test?
config_files.each { |config_file|
  unless File.exists?(File.join($ROOT, 'config', "%s.yml" %[config_file] ))
    class ConfigFileError < StandardError; end;
    raise ConfigFileError, "Missing required config file: config/%s.yml" %[config_file]
  end
}

configure do
  require 'config/initializer'

  config_files.each { |cf| config_file 'config/%s.yml' %[cf] }

  use Rack::Session::Cookie, :secret => settings.credentials['cookie']['secret']

  dbc = settings.database
  # DataMapper::Logger.new($stdout, :debug)
  DataMapper.setup(:default, "mysql://#{dbc[:un]}:#{dbc[:pw]}@#{dbc[:host]}/#{dbc[:db]}")

  # load everything
  require 'app/models/transaction'
  [ 'lib', 'app/helpers', 'app/models', 'app/controllers' ].each { |d|
    Dir.glob("#{d}/**/*.rb").each { |f| require f }
  }

  DataMapper.finalize
  DataMapper.auto_upgrade! unless $DB_BOOTSTRAPPING

  Rabl.register!

  set :views, File.join($ROOT, 'app', 'views')
end

# skip OmniAuth and Pony in test mode
configure :development, :production do |app|

  use OmniAuth::Builder do
    OmniAuth.config.on_failure = Proc.new { |env|
      OmniAuth::FailureEndpoint.new(env).redirect_to_failure
    }

    provider :facebook,
      app.settings.credentials['facebook']['key'],
      app.settings.credentials['facebook']['secret']

    provider :google_oauth2,
      app.settings.credentials['google']['key'],
      app.settings.credentials['google']['secret'],
      { access_type: "offline", approval_prompt: "" }

    provider :github,
      app.settings.credentials['github']['key'],
      app.settings.credentials['github']['secret']
  end

  Pony.options = {
    :from => settings.courier[:from],
    :via => :smtp,
    :via_options => {
      :address    => settings.credentials['courier']['address'],
      :port       => settings.credentials['courier']['port'],
      :user_name  => settings.credentials['courier']['key'],
      :password   => settings.credentials['courier']['secret'],
      :enable_starttls_auto => true,
      :authentication => :plain, # :plain, :login, :cram_md5, no auth by default
      :domain => "HELO", # don't know exactly what should be here
    }
  }
end

configure :production   do Bundler.require(:production)  end
configure :development  do Bundler.require(:development) end