helpers do
  def comlink
    settings.comlink
  end

  def append_user_to_message(payload, user = @user)
    if payload[:client_id] && !payload[:user] && user
      payload.merge!({
        user: JSON.parse(rabl(:"users/show.min", object: user))
      })
    end
  end
end

configure do |app|
  puts ">> Launching AMQP Comlink..."
  begin
    set :comlink, Pibi::AMQP::Producer.new(app.amqp, true)
    at_exit do
      app.comlink.stop
    end
  rescue
    puts "[error] Unable to launch AMQP comlink, messaging will be disabled."
  end
end