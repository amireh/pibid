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
  set :comlink, Pibi::Producer.new(app.amqp)

  EM.next_tick do
    puts ">> Launching AMQP Comlink..."
    app.comlink.start do
      puts ">> Launched"
    end

    at_exit do
      app.comlink.stop
    end
  end
end