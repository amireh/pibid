# encoding: UTF-8

$ROOT ||= File.dirname(__FILE__)
$LOAD_PATH << $ROOT

require 'config/boot'
require 'newrelic_rpm' if ENV['RACK_ENV'] == 'production'
# require 'new_relic/rack/developer_mode' if ENV['RACK_ENV'] == 'development'

# NewRelic::Agent.after_fork(:force_reconnect => true)
Thread.abort_on_exception = true

# use Rack::ShowExceptions
# use NewRelic::Rack::DeveloperMode if ENV['RACK_ENV'] == 'development'

run Sinatra::Application