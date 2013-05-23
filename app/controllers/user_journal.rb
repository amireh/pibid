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
  @account = @user.account

  @journal.operator = self
  @journal.register_factory("account_transactions", :create, method(:account_transactions_create))
  @journal.register_factory("account_transactions", :update, method(:account_transactions_update))
  @journal.add_callback(:on_process) do |*_|
    api_clear!
  end

  begin
    @journal.commit({ graceful: graceful })
  rescue ArgumentError => e
    halt 400, @journal.errors
  end

  unless @journal.errors.empty?
    halt 400, @journal.errors
  end

  # puts @journal.processed.inspect
  # puts @journal.dropped.inspect

  respond_with @journal do |f|
    f.json do
      rabl :"users/journal"
    end
  end
end
