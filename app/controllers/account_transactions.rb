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

      @account.send("#{type}_transactions", Time.utc(y, m, d))
    rescue ArgumentError => e
      halt 400, "Invalid drilldown segment [YYYY/MM/DD]: '#{y}/#{m}/#{d}'"
    end
  end

  def account_transactions_create(account, p = params)
    api_required!({
      amount: nil,
      type:   lambda { |t|
        unless [ 'withdrawal', 'deposit' ].include?(t)
          return "Invalid type '#{t}', accepted types are: deposit and withdrawal"
        end
      }
    }, p)

    api_optional!({
      to: lambda { |account_id|
        unless @to = account.user.accounts.get(account_id)
          return "No such account ##{account_id}"
        end
      }
    }, p)

    api_consume!(:to)

    collection = account.send(api_consume!(:type).to_s.to_plural)

    tx = account_transactions_build(collection.new, account, p)

    if @to
      target = {
        currency: Currency[tx.currency]
      }

      collection = tx.is_a?(Deposit) ? @to.withdrawals : @to.deposits
      spouse = collection.create({
        amount: target[:currency].from(tx.currency, tx.amount),
        currency: target[:currency].name,
        payment_method_id: tx.payment_method_id,
        spouse_id: tx.id
      })

      if spouse.saved?
        tx.spouse = spouse
        tx.save!
      end
    end

    tx
  end

  def account_transactions_update(transaction, p = params)
    api_optional!({
      amount: nil
    }, p)

    tx = account_transactions_build(transaction, transaction.collection.account, p)

    if tx.transfer?
      spouse = tx.spouse
      spouse.update({
        amount: Currency[spouse.currency].from(tx.currency, tx.amount)
      })
    end

    tx
  end

  def account_transactions_build(transaction, account, p = params)
    user = account.user

    parsed_occurence = nil

    api_optional!({
      note:       nil,
      occured_on: lambda { |d|
        unless parsed_occurence = parse_date(d)
          return 'Invalid date, expected String format: MM/DD/YYYY'
        end
      },
      currency:   nil,
      categories: nil,
      payment_method_id: nil
    }, p)

    api_transform! :amount do |a| a.to_f.round(2).to_s end
    api_transform! :occured_on do |d|
      parsed_occurence
    end

    pm = api_consume! :payment_method_id do |pm_id|
      user.payment_methods.get(pm_id) || user.payment_method
    end

    data = {
      payment_method: pm
    }

    if api_has_param?(:categories)
      data[:categories] = (api_consume!(:categories)||[]).map { |cid| user.categories.get(cid) }.reject(&:nil?)
    end

    transaction.attributes = api_params(data)

    unless transaction.save
      halt 400, transaction.errors
    end

    transaction
  end

  def account_transactions_delete(transaction, p = params)
    spouse = transaction.spouse

    unless transaction.destroy
      halt 400, transaction.errors
    end

    if spouse
      spouse.destroy
    end

    true
  end
end

get '/users/:user_id/transactions',
  auth: [ :user ],
  requires: [ :user ],
  provides: [ :json ] do

  api_required!({
    from: lambda { |date|
      unless @from = parse_date(date)
        return 'Invalid :from date, expected format: MM/DD/YYYY'
      end
    },
    to: lambda { |date|
      unless @to = parse_date(date)
        return 'Invalid :to date, expected format: MM/DD/YYYY'
      end
    }
  })

  @transactions = []

  @user.accounts.each do |account|
    @transactions << account.transactions_in({
      begin: @from,
      end: @to
    })
  end

  @transactions.flatten!

  respond_with @transactions do |f|
    f.json { rabl :"transactions/index", collection: @transactions }
  end
end

get '/accounts/:account_id/transactions',
  auth: [ :user ],
  requires: [ :account ],
  provides: [ :json ] do

  api_required!({
    from: lambda { |date|
      unless @from = parse_date(date)
        return 'Invalid :from date, expected format: MM/DD/YYYY'
      end
    },
    to: lambda { |date|
      unless @to = parse_date(date)
        return 'Invalid :to date, expected format: MM/DD/YYYY'
      end
    }
  })

  api_optional!({
    type: lambda { |type|
      unless type && [ 'withdrawal', 'deposit' ].include?(type)
        return 'Invalid :type, must be one of :withdrawal or :deposit'
      end
    }
  })

  options = {}

  api_consume!(:type) do |v|
    options[:type] = case v
    when 'withdrawal'
      Withdrawal
    when 'deposit'
      Deposit
    end
  end

  @transactions = @account.transactions_in({
    begin: @from,
    end: @to
  }, options)

  respond_with @transactions do |f|
    f.json { rabl :"transactions/index", collection: @transactions }
  end
end

get '/accounts/:account_id/transactions/drilldown/:year',
  auth: [ :user ],
  requires: [ :account ],
  provides: [ :json ] do

  @transactions = transactions_in(:yearly, params[:year])

  respond_with @transactions do |f|
    f.json { rabl :"transactions/index", collection: @transactions }
  end
end

get '/accounts/:account_id/transactions/drilldown/:year/:month',
  auth: [ :user ],
  requires: [ :account ],
  provides: [ :json ] do

  @transactions = transactions_in(:monthly, params[:year], params[:month])

  respond_with @transactions do |f|
    f.json { rabl :"transactions/index", collection: @transactions }
  end
end

get '/accounts/:account_id/transactions/drilldown/:year/:month/:day',
  auth: [ :user ],
  requires: [ :account ],
  provides: [ :json ] do

  @transactions = transactions_in(:daily, params[:year], params[:month], params[:day])

  respond_with @transactions do |f|
    f.json { rabl :"transactions/index", collection: @transactions }
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
