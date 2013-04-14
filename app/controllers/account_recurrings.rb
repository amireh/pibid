get '/accounts/:account_id/recurrings',
  auth: :user,
  requires: [ :account ],
  provides: [ :json ] do

  @transies = @account.recurrings

  respond_to do |f|
    f.json { rabl :"recurrings/index" }
  end
end

def build_rtx(rtx)
  @transaction = rtx

  api_transform! :amount    do |v| v.to_f   end
  api_transform! :flow_type do |v| v.to_sym end
  api_transform! :frequency do |v| v.to_sym end
  api_transform! :payment_method do |_| @pm end

  categories = []
  api_consume! :categories do |v| categories = v end

  recurs_on = nil

  this_year = Time.now.year

  case api_param :frequency
  when :monthly
    # only the day is used in this case
    begin
      recurs_on = DateTime.new(this_year, 1, api_param(:monthly_recurs_on_day).to_i)
    rescue
      halt 400, "Bad monthly recurrence day: #{api_param :monthly_recurs_on_day}"
    end

  when :yearly
    # the day and month are used in this case
    begin
      recurs_on = DateTime.new(this_year, api_param(:yearly_recurs_on_month).to_i, api_param(:yearly_recurs_on_day).to_i)
    rescue
      halt 400, "Bad yearly recurrence day or month: #{api_param :yearly_recurs_on_day}, #{yearly_recurs_on_month}"
    end
  else
    recurs_on = DateTime.now
  end

  api_consume! [ :monthly_recurs_on_day, :yearly_recurs_on_month, :yearly_recurs_on_day ]

  @transaction.attributes = api_params({
    recurs_on:  recurs_on,
    active:     api_has_param?(:active) ? api_param(:active) : true
  })

  @transaction.categories = []
  categories.each do |cid|
    unless c = @account.user.categories.get(cid)
      next
    end

    @transaction.categories << c
  end

  unless @transaction.save
    halt 400, @transaction.errors
  end

  # if categories.any?
    # @transaction.save
  # end

  respond_with @transaction do |f|
    f.json { rabl :"recurrings/show" }
  end
end

post '/accounts/:account_id/recurrings',
  auth: :user,
  provides: [ :json ],
  requires: [ :account ] do

  api_required!({
    amount: nil,
    note:   nil,
    flow_type: lambda { |v|
      unless [ 'negative', 'positive' ].include?((v || '').to_s)
        return "flow_type must be either :negative or :positive"
      end
    },
    frequency: lambda { |v|
      case v
      when 'daily'
      when 'monthly'
        unless params.has_key?('monthly_recurs_on_day')
          return ":monthly frequency must be accompanied by a :monthly_recurs_on_day field"
        end
      when 'yearly'
        unless params.has_key?('yearly_recurs_on_day') && params.has_key?('yearly_recurs_on_month')
          return ":yearly frequency must be accompanied by :yearly_recurs_on_day and :yearly_recurs_on_month fields"
        end
      else
        return "frequency must be one of :daily, :monthly, or :yearly"
      end
    }
  })

  api_optional!({
    currency:   nil,
    categories: nil,
    monthly_recurs_on_day: nil,
    yearly_recurs_on_day:  nil,
    yearly_recurs_on_month: nil,
    active: nil,
    payment_method: lambda { |pm_id|
      unless @pm = @account.user.payment_methods.get(pm_id)
        return "No such payment method."
      end
    }
  })

  build_rtx @account.recurrings.new
end

patch '/accounts/:account_id/recurrings/:recurring_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :account, :recurring ] do

  api_optional!({
    amount: nil,
    note:   nil,
    flow_type: lambda { |v|
      unless [ 'negative', 'positive' ].include?((v || '').to_s)
        return "flow_type must be either :negative or :positive"
      end
    },
    frequency: lambda { |v|
      case v
      when 'daily'
      when 'monthly'
        unless params.has_key?('monthly_recurs_on_day')
          return ":monthly frequency must be accompanied by a :monthly_recurs_on_day field"
        end
      when 'yearly'
        unless params.has_key?('yearly_recurs_on_day') && params.has_key?('yearly_recurs_on_month')
          return ":yearly frequency must be accompanied by :yearly_recurs_on_day and :yearly_recurs_on_month fields"
        end
      else
        return "frequency must be one of :daily, :monthly, or :yearly"
      end
    },
    currency:   nil,
    categories: nil,
    monthly_recurs_on_day: nil,
    yearly_recurs_on_day:  nil,
    yearly_recurs_on_month: nil,
    active: nil,
    payment_method: lambda { |pm_id|
      unless @pm = @account.user.payment_methods.get(pm_id)
        return "No such payment method."
      end
    }
  })

  build_rtx @recurring
end


delete '/accounts/:account_id/recurrings/:recurring_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :account, :recurring ] do

  unless @recurring.destroy
    halt 400, @recurring.errors
  end

  blank_halt!
end