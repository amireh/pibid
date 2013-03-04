class Transaction

  # Populates a transaction with fields found in the request params.
  # Handles both newly created (not yet saved) and persistent resources.
  # However, it does _not_ update or save the resource, which is why it's
  # called a populator and not a builder.
  #
  # Accepted params:
  #
  # => amount: Float
  # => currency: String (see Currency)
  # => note: Text
  # => occured_on: String (MM/DD/YYYY)
  # => payment_method: Integer (id)
  # => categories: Array of category ids (strings or integers, doesn't matter)
  #
  # For Recurring transies:
  # => flow_type: one of [ 'positive', 'negative' ]
  # => frequency: one of [ 'daily', 'monthly', 'yearly' ]
  # => if frequency == monthly
  #   => monthly_recurs_on_day: Integer, day of the month the tx should reoccur on
  # => if frequency == yearly
  #   => yearly_recurs_on_day: Integer, day of the year the tx should reoccur on
  #   => yearly_recurs_on_month: Integer, month of the year the tx should reoccur on
  # }
  #
  # @return: the passed transie
  #
  def populate(params)
    self.amount     = params[:amount].to_f        if params.has_key?('amount')
    self.currency   = params[:currency]           if params.has_key?('currency')
    self.note       = params[:note]               if params.has_key?('note')
    self.occured_on = params[:occured_on].to_date if params.has_key?('occured_on')

    if params.has_key?('payment_method')
      self.payment_method = self.account.user.payment_methods.get(params[:payment_method].to_i)

      if self.payment_method.nil?
        puts "payment_method is nil, trying to search by name"
        self.payment_method = self.account.user.payment_methods.first(:name => params[:payment_method])
      end
    end

    if self.recurring?
      self.flow_type = params[:flow_type].to_sym if params.has_key?('flow_type')

      if params.has_key?('frequency')
        self.frequency = params[:frequency].to_sym

        case self.frequency
        when :monthly
          # only the day is used in this case
          if params.has_key?('monthly_recurs_on_day')
            self.recurs_on = DateTime.new(0, 1, params[:monthly_recurs_on_day].to_i)
          end
        when :yearly
          # the day and month are used in this case
          if params.has_key?('yearly_recurs_on_day') && params.has_key?('yearly_recurs_on_month')
            self.recurs_on = DateTime.new(0,
              params[:yearly_recurs_on_month].to_i,
              params[:yearly_recurs_on_day].to_i)
          end
        end # self.frequency types
      end # has frequency
    end # is recurring

    self
  end # populate

  def attach_categories(category_ids)
    if category_ids && category_ids.is_a?(Array)
      self.categories = category_ids.map { |cid| self.account.user.categories.get(cid.to_i) }
    end

    self
  end # attach_categories
end # Transaction

public

route_namespace "/transactions" do
  before do
    restrict_to(:user)
  end

  get :provides => [ :json ] do
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

end

route_namespace "/transactions/bulk" do
  before do
    restrict_to(:user)
  end

  get :provides => [ :json ] do
    limit  = 15
    offset = 0

    if params[:limit]
      limit = params[:limit].to_i if params[:limit].to_i > 0
    end

    if params[:offset]
      offset = params[:offset].to_i if params[:offset].to_i > 0
    end

    render_transactions_bulk(limit,offset)
  end
end


[ 'deposits', 'withdrawals', 'recurrings' ].each do |tx_type|
  route_namespace "/#{tx_type}" do
    before do
      restrict_to(:user)
    end

    if tx_type == 'recurrings'
      # recurring transies index
      get :provides => [ :json ] do
        # TODO: enforce some limit..

        @transies         = current_account.recurrings.all
        @daily_transies   = @transies.all({ frequency: :daily })
        @monthly_transies = @transies.all({ frequency: :monthly })
        @yearly_transies  = @transies.all({ frequency: :yearly })

        rabl :"transactions/recurrings/index"
      end
    end

    post :provides => [ :json ] do
      @tx = @account.send(tx_type).new.populate(params)

      unless @tx.save
        halt 400, @tx.report_errors
      end

      # attach to categories
      @tx.attach_categories(params[:categories] || []).save

      rabl :"transactions/show"
    end

    route_namespace "/#{tx_type}/:tx_id" do
      before do
        restrict_to(:user, with: lambda { |u|
          unless @tx = u.accounts.first.transactions.get(params[:tx_id])
            halt 404
          end

          true
        })
      end

      put :provides => [ :json ] do
        unless @tx.populate(params).attach_categories(params[:categories] || []).save
          halt 400, @tx.report_errors
        end

        rabl :"transactions/show"
      end

      delete :provides => [ :json ] do |tid|
        unless @tx.destroy
          halt 400, @tx.report_errors
        end

        200
      end

    end # ns: /:type/:tx_id
  end # ns: /:type
end # transie type loop