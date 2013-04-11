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

  render_transactions_for(year,month,day)
end


post '/accounts/:account_id/transactions',
  auth: :user,
  provides: [ :json ],
  requires: [ :account ] do

  api_required!({
    amount:     nil,
    type: lambda { |t|
      unless [ 'withdrawal', 'deposit' ].include?(t)
        return "Invalid type '#{t}', accepted types are: deposit and withdrawal"
      end
    }
  })

  api_optional!({
    note:       nil,
    occured_on: lambda { |d|
      begin; d.to_date(false); rescue; return "Invalid date '#{d}', expected format: MM/DD/YYYY"; end
      true
    },
    currency:   nil,
    categories: nil,
    payment_method: lambda { |pm_id|
      unless @pm = @account.user.payment_methods.get(pm_id)
        return "No such payment method."
      end
    }
  })

  type = nil
  api_consume! :type do |v| type = v end

  api_transform! :amount do |a| a.to_f end
  api_transform! :occured_on do |d| d.to_date end
  api_transform! :payment_method do |_| @pm end

  categories = []
  api_consume! :categories do |v| categories = v end

  @transaction = @account.send("#{type}s").new(api_params)

  unless @transaction.save
    halt 400, @transaction.errors
  end

  if categories.any?
    categories.each do |cid|
      unless c = @account.user.categories.get(cid)
        next
      end

      @transaction.categories << c
    end

    @transaction.save
  end

  respond_with @transaction do |f|
    f.json { rabl :"transactions/show" }
  end
end

patch '/accounts/:account_id/transactions/:transaction_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :account, :transaction ] do

  api_optional!({
    amount:     nil,
    note:       nil,
    occured_on: lambda { |d|
      begin; d.to_date(false); rescue; return 'Invalid date, expected format: MM/DD/YYYY'; end
      true
    },
    currency:   nil,
    categories: nil,
    payment_method: lambda { |pm_id|
      unless @pm = @account.user.payment_methods.get(pm_id)
        return "No such payment method."
      end
    }
  })

  api_transform! :occured_on do |d| d.to_date end
  api_transform! :payment_method do |_| @pm end

  api_consume! :categories do |categories|
    @transaction.categories = []

    categories.each do |cid|
      unless c = @account.user.categories.get(cid)
        next
      end

      @transaction.categories << c
    end

    @transaction.save
  end

  unless @transaction.update(api_params)
    halt 400, @transaction.errors
  end

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

  halt 200, '{}'.to_json
end
