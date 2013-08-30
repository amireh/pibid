# encoding: UTF-8

$ROOT ||= File.expand_path( File.join( File.dirname(__FILE__), '..' ) )
$LOAD_PATH << $ROOT

require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

ENV['TZ'] = 'UTC'
Time.zone = 'UTC'

# ----
# Validating that configuration files exist and are readable...
config_files = [ 'application', 'database', 'cookies', 'cors', 'amqp', 'oauth' ]
config_files.each { |config_file|
  unless File.exists?(File.join($ROOT, 'config', "%s.yml" %[config_file] ))
    class ConfigFileError < StandardError; end;
    raise ConfigFileError, "Missing required config file: config/%s.yml" %[config_file]
  end
}

configure do
  require 'lib/version'
  puts "---- Pibi API #{Pibi::VERSION} ----"
  puts ">> Booting..."

  config_files.each { |cf| config_file './%s.yml' %[cf] }

  require "config/initializer"
end
