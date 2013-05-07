get '/accounts/:account_id/transactions/:year',
  auth: [ :user ],
  requires: [ :account ],
  provides: [ :json ] do

  render_transactions_for(params[:year].to_i, 0, 0)
end

get '/accounts/:account_id/transactions/:year/:month',
  auth: [ :user ],
  requires: [ :account ],
  provides: [ :json ] do

  render_transactions_for(params[:year].to_i, params[:month].to_i, 0, false)

  rabl :"transactions/index"
end

get '/accounts/:account_id/transactions/:year/:month/:day',
  auth: [ :user ],
  requires: [ :account ],
  provides: [ :json ] do

  render_transactions_for(params[:year].to_i, params[:month].to_i, params[:day].to_i, false)

  rabl :"transactions/index"
end

get '/accounts/:account_id/transactions',
  auth: :user,
  requires: [ :account ],
  provides: [ :json ] do

  year  = Time.now.year
  month = 0
  day   = 0

  if params[:year]
    year = params[:year].to_i if params[:year].to_i != 0
  end

  if params[:month]
    month = params[:month].to_i if params[:month].to_i != 0
  end

  if params[:day]
    day = params[:day].to_i if params[:day].to_i != 0
  end

  render_transactions_for(year,month,day, false)

  rabl :"transactions/index"
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
