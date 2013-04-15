configure do
  Rabl.configure do |config|
    config.escape_all_output = true
  end

  Rabl.register!
end