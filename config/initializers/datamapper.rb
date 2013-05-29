configure do
  dbc = settings.database
  # DataMapper::Logger.new($stdout, :debug)
  use Rack::Session::Moneta, :store => Moneta.new(:DataMapper, {
    repository: :default,
    setup: "mysql://#{dbc[:un]}:#{dbc[:pw]}@#{dbc[:host]}/#{dbc[:db]}"
  })
  # DataMapper.setup(:default, "mysql://#{dbc[:un]}:#{dbc[:pw]}@#{dbc[:host]}/#{dbc[:db]}")
  DataMapper.finalize
  DataMapper.auto_upgrade! unless $DB_BOOTSTRAPPING
end