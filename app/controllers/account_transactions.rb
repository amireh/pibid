helpers do
  def transactions_in(type, y, m = nil, d = nil)
    y = (y || 0).to_i if (y || '').is_a? String
    m = (m || 0).to_i if (m || '').is_a? String
    d = (d || 0).to_i if (d || '').is_a? String

    # make sure the given date is sane
    begin
      case type
      when :yearly
        raise ArgumentError if y == 0
        m, d = 1, 1
      when :monthly
        d = 1
      when :daily
      end

      current_account.send("#{type}_transactions", Time.new(y, m, d))
    rescue ArgumentError => e
      halt 400, "Invalid drilldown segment [YYYY/MM/DD]: '#{y}/#{m}/#{d}'"
    end
  end

  def account_transactions_create(account, p = params)
    api_required!({
      amount:     nil,
      type: lambda { |t|
        unless [ 'withdrawal', 'deposit' ].include?(t)
          return "Invalid type '#{t}', accepted types are: deposit and withdrawal"
        end
      }
    }, p)

    api_optional!({
      note:       nil,
      occured_on: lambda { |d|
        begin
          d.pibi_to_datetime(false)
        rescue
          return 'Invalid date, expected String format: MM/DD/YYYY, or epoch integer timestamp'
        end
      },
      currency:   nil,
      categories: nil,
      payment_method_id: nil
    }, p)

    type = api_consume! :type

    api_transform! :amount do |a| a.to_f.round(2).to_s end
    api_transform! :occured_on do |d| d.pibi_to_datetime end

    pm = api_consume! :payment_method_id do |pm_id|
      account.user.payment_methods.get(pm_id) || account..payment_method
    end

    categories  = api_consume!(:categories) || []
    transaction = account.send("#{type}s").new(api_params({ payment_method: pm }))

    unless transaction.save
      halt 400, transaction.errors
    end

    if categories.any?
      transaction.categories = categories.map { |cid| account.user.categories.get(cid) }.reject(&:nil?)
      transaction.save
    end

    transaction
  end

  def account_transactions_update(transaction, p = params)
    account = transaction.account

    api_optional!({
      amount:     nil,
      note:       nil,
      occured_on: lambda { |d|
        begin
          d.pibi_to_datetime(false)
        rescue
          return 'Invalid date, expected format: MM/DD/YYYY'
        end
      },
      currency:   nil,
      categories: nil,
      payment_method_id: nil
    }, p)

    api_transform! :amount do |a| a.to_f.round(2).to_s end
    api_transform! :occured_on do |d| d.pibi_to_datetime end
    # api_transform! :payment_method_id do |_| @pm end
    pm = api_consume! :payment_method_id do |pm_id|
      @user.payment_methods.get(pm_id) || @user.payment_method
    end

    api_consume! :categories do |categories|
      categories ||= []
      transaction.categories = categories.map { |cid| account.user.categories.get(cid) }.reject(&:nil?)
      transaction.save
    end

    unless transaction.update(api_params({ payment_method: pm }))
      halt 400, transaction.errors
    end

    transaction
  end

  def account_transactions_delete(transaction, p = params)
    unless transaction.destroy
      halt 400, transaction.errors
    end

    true
  end
end

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

  @transaction = account_transactions_create(@account, params)

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

  account_transactions_delete(@transaction)

  blank_halt! 205
end
