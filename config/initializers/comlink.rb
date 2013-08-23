helpers do
  def comlink
    settings.comlink
  end

  # def notify(*args)
  #   comlink.notify(args)
  # end
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