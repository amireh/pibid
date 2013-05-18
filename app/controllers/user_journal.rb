post '/users/:user_id/journal',
  auth:     [ :user ],
  provides: [ :json ],
  requires: [ :user ] do

  # puts "Journal parameters: #{params}"
  graceful = params[:graceful] || true

  api_optional!({
    create: lambda  { |entries| validate_journal_entries(entries, [ 'id', 'scope', 'data' ]) },
    update: lambda  { |entries| validate_journal_entries(entries, [ 'id', 'scope', 'data' ]) },
    destroy: lambda { |entries| validate_journal_entries(entries, [ 'id', 'scope' ]) },
  })

  api_consume! :create do |v|  entries[:create]  = v end
  api_consume! :update do |v|  entries[:update]  = v end
  api_consume! :destroy do |v| entries[:destroy] = v end

  api_clear!

  Journal.add_callback(:on_process, lambda { api_clear! })

  @journal = Journal.new(entries[:create], entries[:update], entries[:destroy])

  catch :halt do
    @journal.commit({ graceful: true })
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
