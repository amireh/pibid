configure do
  use Rack::ShowExceptions

  set :comlink, Object.new
  set :logging, true
  set :dump_errors, true
  set :raise_errors, true
  set :show_exceptions, true

  puts "in test environment"

  comlink = settings.comlink

  def comlink.broadcast(*args)
    true
  end

  def comlink.run(*args)
    true
  end

  def comlink.stop(*args)
    true
  end
end