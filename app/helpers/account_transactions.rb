helpers do
  def render_transactions_for(year = Time.now.year, month = Time.now.month, day = Time.now.day, do_render = true)
    year  = year.to_i   if year.is_a? String
    month = month.to_i  if month.is_a? String
    day   = day.to_i    if day.is_a? String

    # make sure the given date is sane
    begin
      @date = Time.new(year, month == 0 ? 1 : month, day == 0 ? 1 : day)
    rescue ArgumentError => e
      halt 400, "Invalid transaction period YYYY/MM/DD: '#{year}/#{month}/#{day}'"
    end

    if day > 0
      # daily transaction view
      @drilldown = "daily"

      @transies = current_account.daily_transactions(Time.new(year,month,day))
      # @drilled_transies = { "0" => @transies }
    elsif month > 0
      # monthly transaction view
      @drilldown = "monthly"
      @transies = current_account.monthly_transactions(Time.new(year, month, 1))

      # partition into days
      # @drilled_transies = {}
      # @transies.each { |tx|
      #   @drilled_transies[tx.occured_on.day] ||= []
      #   @drilled_transies[tx.occured_on.day] <<  tx
      # }
    else
      # yearly transaction view
      @drilldown = "yearly"
      @transies = current_account.yearly_transactions(Time.new(year, 1, 1))

      # partition into months
      # @drilled_transies = {}#Array.new(13, [])
      # @drilled_transies = Array.new(13, [])
      # @transies.each { |tx|
      #   @drilled_transies[tx.occured_on.month] ||= []
      #   @drilled_transies[tx.occured_on.month] <<  tx
      # }
    end

    @balance = current_account.balance_for(@transies)

    rabl :"transactions/drilldowns/#{@drilldown}" if do_render
  end

  def account_transactions_create(p = params)
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
      payment_method_id: lambda { |pm_id|
        unless @pm = @account.user.payment_methods.get(pm_id)
          return "No such payment method."
        end
      }
    }, p)

    type = nil
    api_consume! :type do |v| type = v end

    api_transform! :amount do |a| a.to_f end
    api_transform! :occured_on do |d| d.pibi_to_datetime end
    # api_transform! :payment_method_id do |_| @pm end

    categories = []
    api_consume! :categories do |v| categories = v end

    transaction = @account.send("#{type}s").new(api_params)

    unless transaction.save
      halt 400, transaction.errors
    end

    if categories.any?
      categories.each do |cid|
        unless c = @account.user.categories.get(cid)
          next
        end

        transaction.categories << c
      end

      transaction.save
    end

    transaction
  end

  def account_transactions_update(transaction = @transaction, p = params)
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
      payment_method_id: lambda { |pm_id|
        unless @pm = @account.user.payment_methods.get(pm_id)
          return "No such payment method."
        end
      }
    }, p)

    api_transform! :amount do |a| a.to_f end
    api_transform! :occured_on do |d| d.pibi_to_datetime end
    # api_transform! :payment_method_id do |_| @pm end

    api_consume! :categories do |categories|
      transaction.categories = []

      categories.each do |cid|
        unless c = @account.user.categories.get(cid)
          next
        end

        transaction.categories << c
      end

      transaction.save
    end

    unless transaction.update(api_params)
      halt 400, transaction.errors
    end

    transaction
  end
end