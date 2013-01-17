route_namespace '/users/:user_id/reports' do
  condition do
    restrict_to(:user, with: { id: params[:user_id].to_i })
  end

  get '/yearly' do
    @segments = {}

    for i in 0..(Time.now.year - current_account.transactions.last.occured_on.year)
      year = Time.new(Time.now.year - i, 1, 1)
      transies = current_account.yearly_transactions(year)
      @segments[year.year] = {
        balance: current_account.balance_for(transies),
        nr_transies: transies.count
      }
    end

    erb :"/reports/yearly"
  end

  get '/:year' do |year|
    pass if year.to_i == 0

    @year  = year.to_i if year.is_a? String
    month = Time.now.month
    day   = Time.now.day

    # make sure the given date is sane
    begin
      @this_year = @date = Time.new(year, month == 0 ? 1 : month, day == 0 ? 1 : day)
      @next_year = Timetastic.next(1, @date).year
    rescue ArgumentError => e
      halt 400, "Invalid transaction period YYYY/MM/DD: '#{year}/#{month}/#{day}'"
    end

    @transies     = current_account.yearly_transactions(Time.new(year, 1, 1))
    @deposits     = current_account.yearly_deposits(Time.new(year, 1, 1))
    @withdrawals  = current_account.yearly_withdrawals(Time.new(year, 1, 1))

    @balance      = current_account.balance_for(@transies).to_f.round(2)
    @spendings    = current_account.balance_for(@withdrawals).to_f.round(2)
    @earnings     = current_account.balance_for(@deposits).to_f.round(2)

    @savings      = @earnings - @spendings.abs.to_f.round(2)
    @savings      = 0 if @savings < 0
    @segments     = {}

    for i in 1..12 do
      @segments[i] = { balance: 0.0, nr_transies: 0 }
    end

    @transies.each { |tx|
      s = @segments[tx.occured_on.month.to_i]
      s[:balance] = tx + s[:balance]
      s[:nr_transies] += 1
    }

    erb :"/reports/drilldowns/yearly"
  end
end
