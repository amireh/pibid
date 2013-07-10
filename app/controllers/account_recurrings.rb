helpers do
  def account_recurrings_create(account, p = params)
    account_recurrings_build(account.recurrings.new, p)
  end

  def account_recurrings_update(rtx, p = params)
    account_recurrings_build(rtx, p)
  end

  def account_recurrings_build(rtx, p)
    transaction, account, user = rtx, rtx.account, rtx.account.user

    base_params = {
      amount: nil,
      note:   nil,
      flow_type: nil,
      frequency: nil
    }

    if !rtx.saved?
      api_required!(base_params, p)
    else
      api_optional!(base_params, p)
    end

    case api_param :frequency
    when 'monthly'
      api_required!({
        recurs_on_day: nil
      }, p)
    when 'yearly'
      api_required!({
        recurs_on_day: nil,
        recurs_on_month: nil
      }, p)
    end

    api_optional!({
      currency:   nil,
      categories: nil,
      recurs_on_day: nil,
      recurs_on_month: nil,
      active: nil,
      payment_method_id: lambda { |pm_id|
        unless @pm = account.user.payment_methods.get(pm_id)
          return "No such payment method."
        end
      }
    }, p)

    api_transform! :amount    do |v| v.to_f.round(2).to_s end
    api_transform! :flow_type do |v| v.to_sym end
    api_transform! :frequency do |v| v.to_sym end

    data = {
      active:         api_has_param?(:active) ? api_param(:active) : true,
      payment_method: @pm || user.payment_method,
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

  def account_recurrings_delete(rtx, p = params)
    unless rtx.destroy
      halt 400, rtx.errors
    end

    true
  end
end

get '/accounts/:account_id/recurrings',
  auth: :user,
  requires: [ :account ],
  provides: [ :json ] do

  @transies = @account.recurrings

  respond_with @transies do |f|
    f.json { rabl :"recurrings/index", collection: @transies }
  end
end

post '/accounts/:account_id/recurrings',
  auth: :user,
  provides: [ :json ],
  requires: [ :account ] do

  @transaction = account_recurrings_create(@account, params)

  respond_with @transaction do |f|
    f.json { rabl :"recurrings/show" }
  end
end

get '/accounts/:account_id/recurrings/:recurring_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :account, :recurring ] do

  @transaction = @recurring

  respond_with @transaction do |f|
    f.json { rabl :"recurrings/show" }
  end
end

patch '/accounts/:account_id/recurrings/:recurring_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :account, :recurring ] do

  @transaction = account_recurrings_update(@recurring, params)

  respond_with @transaction do |f|
    f.json { rabl :"recurrings/show" }
  end
end

delete '/accounts/:account_id/recurrings/:recurring_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :account, :recurring ] do

  account_recurrings_delete(@recurring, params)

  blank_halt! 205
end