helpers do
  def render_transactions_for(year = Time.now.year, month = Time.now.month, day = Time.now.day)
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
      @drilled_transies = { "0" => @transies }
    elsif month > 0
      # monthly transaction view
      @drilldown = "monthly"
      @transies = current_account.monthly_transactions(Time.new(year, month, 1))

      # partition into days
      @drilled_transies = {}
      @transies.each { |tx|
        @drilled_transies[tx.occured_on.day] ||= []
        @drilled_transies[tx.occured_on.day] <<  tx
      }
    else
      # yearly transaction view
      @drilldown = "yearly"
      @transies = current_account.yearly_transactions(Time.new(year, 1, 1))

      # partition into months
      @drilled_transies = {}#Array.new(13, [])
      # @drilled_transies = Array.new(13, [])
      @transies.each { |tx|
        @drilled_transies[tx.occured_on.month] ||= []
        @drilled_transies[tx.occured_on.month] <<  tx
      }
    end

    @balance  = current_account.balance_for(@transies)

    rabl :"transactions/drilldowns/#{@drilldown}"
  end
end