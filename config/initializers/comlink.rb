module Pibi
  class Comlink
    def initialize()
      @connection, @channel, @exchange = nil,nil,nil
      @queued = []
      @broadcast_lock = Mutex.new

      super()
    end

    def log(msg)
      puts ">> [comlink]: #{msg}"
    end

    def lock(&callback)
      @broadcast_lock.synchronize do
        yield self if block_given?
      end
    end

    def run(options)
      log "connecting to broker"

      log "AMQP connection settings:"
      log "\tHost: #{options['host']}"
      log "\tPort: #{options['port']}"
      log "\tUser: #{options['user']}"
      log "\tPassword: #{options['password'].length}"
      log "\tExchange: #{options['exchange']}"

      AMQP.connect("amqp://#{options['user']}:#{options['password']}@#{options['host']}:#{options['port']}") do |connection|
        @connection = connection
        log "connection established, opening channel..."

        AMQP::Channel.new(connection) do |channel|
          @channel = channel
          log "channel open, passively declaring exchange..."

          exchange_options = {
            durable:      true,
            auto_delete:  false,
            passive:      true
          }

          channel.fanout(options['exchange'], exchange_options) do |exchange, declare_ok|
            log "ready for broadcasting to '#{options['exchange']}'"

            @exchange = exchange
            @queued.each { |d| broadcast(d) }

            lock do
              @queued = []
            end
          end
        end
      end
    end

    def broadcast(data)
      if !@exchange
        return __queue(data)
      end

      # puts "broadcasting: #{data}"

      EM.next_tick do
        lock do
          @exchange.publish( data.to_json )
        end
      end

      self
    end

    def __queue(data)
      lock do
        @queued << data
      end
    end

    def stop(&callback)
      log "disconnecting from broker"

      @connection && @connection.close do
        log "shutting down"
        yield(self) if block_given?
        Thread.current.exit
      end
    end
  end
end

configure do |app|
  at_exit do
    if settings.respond_to?(:comlink)
      settings.comlink.stop
    elsif settings.respond_to?(:comlink_thread)
      Thread.kill(settings.comlink_thread)
    end
  end


  EM.next_tick do
    puts ">> Launching AMQP Comlink..."
    set :comlink_thread, Thread.new {
      app.set :comlink, Pibi::Comlink.new
      app.comlink.run(app.amqp)

      puts ">> Launched"
    }
  end

end