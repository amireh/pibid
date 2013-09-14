helpers do
  def user_accounts_update(account, p = params)
    api_optional!({
      currency: lambda { |iso|
        unless Currency[(iso || '').to_s]
          return "Unrecognized currency ISO code."
        end
      }
    }, p)


    unless account.update(api_params)
      halt 400, account.errors
    end

    account
  end
end

get '/users/:user_id/accounts/:account_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :user, :account ] do

  respond_with @account do |f|
    f.json {
      rabl :"accounts/show"
    }
  end
end

patch '/users/:user_id/accounts/:account_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :user, :account ] do

  @account = user_accounts_update(@account, params)

  blank_halt! if params[:no_object]

  respond_with @account do |f|
    f.json {
      rabl :"accounts/show"
    }
  end
end

put '/users/:user_id/accounts/:account_id/purge',
  auth: :user,
  provides: [ :json ],
  requires: [ :user, :account ] do

  @account.transactions.destroy
  @account.recurrings.destroy

  @account = @account.refresh

  halt 501 if @account.transactions.length > 0 || @account.recurrings.length > 0

  respond_with @account do |f|
    f.json {
      rabl :"accounts/show"
    }
  end
end