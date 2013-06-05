# encoding: UTF-8

$ROOT ||= File.dirname(__FILE__)
$LOAD_PATH << $ROOT

require 'config/boot'

Thread.abort_on_exception = true

use Rack::ShowExceptions
run Sinatra::Application