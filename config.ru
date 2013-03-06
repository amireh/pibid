require './app'
use Rack::ShowExceptions
use Rack::PostBodyContentTypeParser
run Sinatra::Application
