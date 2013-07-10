module Pibi
  class Comlink
    def initialize()
      @connection, @channel, @exchange = nil,nil,nil
      @broadcast_lock = Mutex.new
      @exchanges = {
        sync:     { object: nil, key: '', queued: [], type: "fanout" },
        reports:  { object: nil, key: '', queued: [], type: "direct" }
      }

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
      log "\tCloud Sync Exchange: #{options['exchanges']['sync']}"
      log "\tReports Exchange:    #{options['exchanges']['reports']}"

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

          @exchanges.each_pair do |exkey, h|
            h[:key] = options['exchanges'][exkey.to_s]

            channel.send(h[:type], h[:key], exchange_options) do |e,declare_ok|
              log "ready for broadcasting to '#{h[:key]}'"

              h[:object] = e
              h[:queued].each { |d| broadcast(d) }

              lock do
                h[:queued] = []
              end
            end
          end

        end
      end
    end

    def set_debug(flag)
      @debug = flag
    end

    def broadcast(key, data, options = {})
      key = key.to_sym

      if !exchange = @exchanges[key][:object]
        return __queue(key, data)
      end

      # puts "broadcasting: #{data}"

      EM.next_tick do
        lock do
          begin
            exchange.publish( data.to_json, options || {} )
          rescue JSON::NestingError => e
            if @debug
              puts data
              raise e
            end
          end
        end
      end

      self
    end

    def __queue(key, data)
      lock do
        @exchanges[key.to_sym][:queued] << data
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
      app.comlink.set_debug settings.development?

      puts ">> Launched"
    }
  end

end