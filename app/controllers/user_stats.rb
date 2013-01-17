route_namespace '/users/:user_id/stats' do

  condition do
    restrict_to(:user, with: { :id => params[:user_id].to_i })
  end

  def range_from_params()
    halt 400, "Missing :begin and :end date range arguments." unless params[:begin] && params[:end]

    b, e = nil

    begin
      b = params[:begin].to_date(false).to_time
      e = params[:end].to_date(false).to_time
    rescue ArgumentError => e
      halt 400, "Invalid date range in [#{b}, #{e}]. Accepted format: MM-DD-YYYY"
    end

    halt 400, "Invalid date range." if e < b

    { :begin => b, :end => e }
  end

  def transactions_in(b, e, q = {}, r = nil)
    (r || current_account).transactions_in(range_from_params, q)
  end

  # Stat structure:
  #   [...,
  #    {
  #     name:  string,
  #     color: string,
  #     ratio: float,
  #     count: integer
  #    },
  #   ...]
  get '/payment_methods/ratio.json' do
    s = []

    transies = transactions_in(params[:begin], params[:end])

    if @user.payment_methods.any? && transies.count > 0
      @user.payment_methods.each do |pm|
        pm_transies = transactions_in(params[:begin], params[:end], {}, pm)
        s << {
          name:  pm.name,
          color: pm.color,
          ratio: pm_transies.count.to_f / transies.count * 100.0,
          count: pm_transies.count
        }

        s.last[:ratio] = s.last[:ratio].round(0) if params[:round]
      end
    end

    s.to_json
  end

  get '/categories/yearly/spendings.json' do |cid|
    s = { names: [], spendings: [] }
    current_user.categories.each do |c|
      s[:names] << c.name
      s[:spendings] << c.balance_for(c.transactions_in(range_from_params, { type: Withdrawal })).to_f.abs.round(2)
    end
    s.to_json
  end

  get '/categories/top_spending.json' do
    s = []
    r = range_from_params
    q = { type: Withdrawal }

    categories = current_user.categories
    categories.sort! { |a,b|
      a.balance_for(a.transactions_in(r,q)) <=> b.balance_for(b.transactions_in(r,q))
    }

    ub = params[:ub].to_i - 1 if params[:ub]
    ub ||= 2
    if ub > categories.length
      ub = categories.length
    end

    categories.map { |c| c.name }[0..ub].to_json
  end

  get '/categories/top_earning.json' do
    s = []
    r = range_from_params
    q = { type: Deposit }

    categories = current_user.categories
    categories.sort! { |a,b|
      a.balance_for(a.transactions_in(r,q)) <=> b.balance_for(b.transactions_in(r,q))
    }.reverse!

    ub = params[:ub].to_i - 1 if params[:ub]
    ub ||= 2
    if ub > categories.length
      ub = categories.length
    end

    categories.map { |c| c.name }[0..ub].to_json
  end

  get '/accounts/:account_id/monthly/balance.json' do
    r = range_from_params
    m = r[:begin]
    s = []
    months = Timetastic.months_between(r[:begin], r[:end])

    for i in 1..months
      s << current_account.monthly_balance(m).to_f.round(2)
      m = 1.month.ahead(m)
    end

    s.to_json
  end

  get '/accounts/:account_id/monthly/savings.json' do
    r = range_from_params
    m = r[:begin]
    s = { savings: [], spendings: [] }
    months = Timetastic.months_between(r[:begin], r[:end])

    for i in 1..months
      earnings  = current_account.monthly_earnings(m)
      spendings = current_account.monthly_spendings(m)

      # saved anything?
      savings = earnings - spendings.abs
      savings = 0 if savings < 0

      s[:savings] << savings.to_f.round(2)
      s[:spendings] << spendings.abs.to_f.round(2)

      m = 1.month.ahead(m)
    end

    s.to_json
  end

end