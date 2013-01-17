private

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
def populate_transie(tx)
  tx.amount     = params[:amount].to_f        if params.has_key?('amount')
  tx.currency   = params[:currency]           if params.has_key?('currency')
  tx.note       = params[:note]               if params.has_key?('note')
  tx.occured_on = params[:occured_on].to_date if params.has_key?('occured_on')

  if params.has_key?('payment_method')
    tx.payment_method = @user.payment_methods.get(params[:payment_method].to_i)
  end

  if tx.recurring?
    tx.flow_type = params[:flow_type].to_sym if params.has_key?('flow_type')

    if params.has_key?('frequency')
      tx.frequency = params[:frequency].to_sym

      case tx.frequency
      when :monthly
        # only the day is used in this case
        if params.has_key?('monthly_recurs_on_day')
          tx.recurs_on = DateTime.new(0, 1, params[:monthly_recurs_on_day].to_i)
        end
      when :yearly
        # the day and month are used in this case
        if params.has_key?('yearly_recurs_on_day') && params.has_key?('yearly_recurs_on_month')
          tx.recurs_on = DateTime.new(0,
            params[:yearly_recurs_on_month].to_i,
            params[:yearly_recurs_on_day].to_i)
        end
      end # tx.frequency types
    end # has frequency
  end # is recurring

  tx
end # populate_transies

def attach_transie_categories(tx, category_ids)
  if category_ids && category_ids.is_a?(Array) && category_ids.any?
    category_ids.each { |cid| tx.categories << @user.categories.get(cid) }
  end

  tx
end

public

[ 'deposits', 'withdrawals', 'recurrings' ].each do |tx_type|

  route_namespace "/accounts/:account_id/transactions" do
    condition do
      restrict_to(:user, { with: lambda { |u| u.accounts.first.id == params[:account_id].to_i }})
    end

    get '/transactions/:year', auth: :user do |year|
      pass if year.to_i == 0

      render_transactions_for(year, 0, 0)
    end

    get '/transactions/:year/:month', auth: :user do |year, month|
      pass if year.to_i == 0 || month.to_i == 0

      render_transactions_for(year,month,0)
    end

    get '/transactions/:year/:month/:day', auth: :user do |year, month, day|
      pass if year.to_i == 0 || month.to_i == 0 || day.to_i == 0

      render_transactions_for(year,month,day)
    end
  end

  route_namespace "/accounts/:account_id/#{tx_type}" do

    condition do
      restrict_to(:user, { with: lambda { |u| u.accounts.first.id == params[:account_id].to_i }})
    end

    post do
      tx = populate_transie(@account.send(tx_type).new)

      if tx.save && tx.saved?
        # t.account.save!
        flash[:notice] = "Transaction created."

        # attach to categories
        attach_transie_categories(tx, params[:categories]).save
      else
        flash[:error] = tx.all_errors
      end

      redirect back
    end

    put "/:tid" do |tid|
      unless tx = @account.transactions.get(tid)
        halt 400, "No such transie"
      end

      populate_transie(tx)
      attach_transie_categories(tx, params[:categories])

      if tx.save
        flash[:notice] = "Transie##{tx.id} was updated."
      else
        flash[:error] = tx.all_errors
      end

      redirect back
    end

    delete "/:tid" do |tid|
      unless t = @account.transactions.get(tid)
        halt 400, 'No such transie'
      end

      unless t.destroy
        flash[:error] = t.all_errors
        return redirect back
      end

      flash[:notice] = "Transaction was removed."

      redirect back
    end

    if tx_type == 'recurrings'
      get do
        # TODO: enforce some limit..

        @transies         = current_account.recurrings.all
        @daily_transies   = @transies.all({ frequency: :daily })
        @monthly_transies = @transies.all({ frequency: :monthly })
        @yearly_transies  = @transies.all({ frequency: :yearly })

      end
    else
      get do
        current_account.send(tx_type).all
      end
    end

  end # namespace['/transactions/:type']
end # transie type loop