get '/accounts/:account_id/transactions/drilldown/:year',
  auth: [ :user ],
  requires: [ :account ],
  provides: [ :json ] do

  @transies = transactions_in(:yearly, params[:year])

  respond_with @transies do |f|
    f.json { rabl :"transactions/index", collection: @transies }
  end
end

get '/accounts/:account_id/transactions/drilldown/:year/:month',
  auth: [ :user ],
  requires: [ :account ],
  provides: [ :json ] do

  @transies = transactions_in(:monthly, params[:year], params[:month])

  respond_with @transies do |f|
    f.json { rabl :"transactions/index", collection: @transies }
  end
end

get '/accounts/:account_id/transactions/drilldown/:year/:month/:day',
  auth: [ :user ],
  requires: [ :account ],
  provides: [ :json ] do

  @transies = transactions_in(:daily, params[:year], params[:month], params[:day])

  respond_with @transies do |f|
    f.json { rabl :"transactions/index", collection: @transies }
  end
end

post '/accounts/:account_id/transactions',
  auth: :user,
  provides: [ :json ],
  requires: [ :account ] do

  @transaction = account_transactions_create(params)

  respond_with @transaction do |f|
    f.json { rabl :"transactions/show" }
  end
end

get '/accounts/:account_id/transactions/:transaction_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :account, :transaction ] do

  respond_with @transaction do |f|
    f.json { rabl :"transactions/show" }
  end
end

patch '/accounts/:account_id/transactions/:transaction_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :account, :transaction ] do

  @transaction = account_transactions_update(@transaction, params)

  respond_with @transaction do |f|
    f.json { rabl :"transactions/show" }
  end
end


delete '/accounts/:account_id/transactions/:transaction_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :account, :transaction ] do

  unless @transaction.destroy
    halt 400, @transaction.errors
  end

  blank_halt!
end
