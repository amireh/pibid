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
    halt 400, @journal.errors
  end

  unless @journal.errors.empty?
    halt 400, @journal.errors
  end

  respond_with @journal do |f|
    f.json do
      rabl :"users/journal"
    end
  end
end
