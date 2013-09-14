# encoding: UTF-8

$ROOT ||= File.dirname(__FILE__)
$LOAD_PATH << $ROOT

require 'config/boot'
require 'newrelic_rpm'
require 'new_relic/rack/developer_mode'

# NewRelic::Agent.after_fork(:force_reconnect => true)
Thread.abort_on_exception = true

use Rack::ShowExceptions
use NewRelic::Rack::DeveloperMode

run Sinatra::Application