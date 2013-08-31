get '/users/:user_id/journals/:journal_id',
  auth:     [ :user ],
  provides: [ :json ],
  requires: [ :user, :journal ] do

  respond_with @journal do |f|
    f.json { @journal.data }
  end
end

post '/users/:user_id/journal',
  auth:     [ :user ],
  provides: [ :json ],
  requires: [ :user ] do

  # puts "Journal parameters: #{params}"
  graceful = params.has_key?('graceful') ? params['graceful'] : true

  api_optional!({
    scopemap: nil,
    entries:  nil
  })

  @journal = @user.journals.new(api_params)

  @journal.add_callback(:on_process) do |*_|
    api_clear!
  end

  begin
    @journal.commit(self, { graceful: graceful })
  rescue ArgumentError => e
    errmsg = @journal.errors
    errmsg = e.message if errmsg.empty?

    puts e.inspect
    puts e.backtrace

    halt 400, errmsg
  end

  unless @journal.errors.empty?
    halt 400, @journal.errors
  end

  original_processed_map = @journal.processed.clone

  @journal.shadowmap.each_pair { |scope, collections|
    collections.each_pair { |collection, entries|
      operations = @journal.processed[scope][collection]

      entries.each_pair do |shadow_id, genuine_id|
        operations.each_pair do |op, entries|

          entries.select { |entry| entry[:id] == shadow_id }.each { |entry|
            entry[:id] = genuine_id
          }
        end
      end
    }
  }

  @journal.data = rabl(:"users/journals/show.min")

  if @journal.save
    comlink.push('notifications', 'journal_committed', {
      client_id: @user.id,
      journal_id: @journal.id
    })
  end

  @journal.processed = original_processed_map

  respond_with @journal do |f|
    f.json {
      rabl(:"users/journals/show")
    }
  end
end
