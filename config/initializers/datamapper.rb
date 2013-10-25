configure do
  dbc = settings.database
  # DataMapper::Logger.new($stdout, :debug)
  cookie_settings = {
    domain: settings.cookies['domain'],
    path:   settings.cookies['path'],
    key:    settings.cookies['key'],
    secret: settings.cookies['secret'],
    secure: settings.cookies['secure'],
    expire_after: 2.weeks,
    store: Moneta.new(:DataMapper, {
      repository: :default,
      setup: "mysql://#{dbc[:un]}:#{dbc[:pw]}@#{dbc[:host]}:#{dbc[:port]}/#{dbc[:db]}"
    })
  }

  puts ">> Cookie settings: "
  puts ">> \tDomain: #{cookie_settings[:domain]}"
  puts ">> \tPath: #{cookie_settings[:path]}"
  puts ">> \tKey: #{cookie_settings[:key]}"
  puts ">> \tSecret: #{cookie_settings[:secret].length}"
  puts ">> \tSecure? #{!!cookie_settings[:secure]}"

  puts ">> Database connection: "
  puts ">> \tAdapter: mysql"
  puts ">> \tHost: #{dbc[:host]}"
  puts ">> \tDatabase: #{dbc[:db]}"
  puts ">> \tUsername: #{dbc[:un]}"
  puts ">> \tPassword: #{dbc[:pw].length}"

  use Rack::Session::Moneta, cookie_settings
  # DataMapper.setup(:default, "mysql://#{dbc[:un]}:#{dbc[:pw]}@#{dbc[:host]}/#{dbc[:db]}")
  DataMapper.finalize
  DataMapper.auto_upgrade! unless $DB_BOOTSTRAPPING
end