# encoding: UTF-8

$ROOT ||= File.dirname(__FILE__)
$LOAD_PATH << $ROOT

require 'config/boot'

use Rack::ShowExceptions
run Sinatra::Application