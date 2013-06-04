configure do
  dbc = settings.database
  # DataMapper::Logger.new($stdout, :debug)
  use Rack::Session::Moneta, :domain => settings.cookie_domain,
  :store => Moneta.new(:DataMapper, {
    repository: :default,
    setup: "mysql://#{dbc[:un]}:#{dbc[:pw]}@#{dbc[:host]}/#{dbc[:db]}"
  })
  # DataMapper.setup(:default, "mysql://#{dbc[:un]}:#{dbc[:pw]}@#{dbc[:host]}/#{dbc[:db]}")
  DataMapper.finalize
  DataMapper.auto_upgrade! unless $DB_BOOTSTRAPPING
end