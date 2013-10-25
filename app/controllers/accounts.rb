helpers do
  def user_accounts_create(user, p = params)
    api_required!({
      label: nil,
      currency: lambda { |iso|
        unless Currency[(iso || '').to_s]
          return "Unrecognized currency ISO code."
        end
      }
    }, p)

    account = user.accounts.create(api_params)

    unless account.saved?
      halt 400, account.errors
    end

    account
  end

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

  def user_accounts_delete(account, p = params)
    unless account.destroy
      halt 400, account.errors
    end

    true
  end
end

post '/users/:user_id/accounts',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user ] do

  @account = user_accounts_create(@user, params)

  respond_with @account do |f|
    f.json { rabl :"accounts/show" }
  end
end

get '/users/:user_id/accounts',
  auth: :user,
  provides: [ :json ],
  requires: [ :user ] do

  @accounts = @user.accounts

  respond_with @accounts do |f|
    f.json {
      rabl :"accounts/index"
    }
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

delete '/users/:user_id/accounts/:account_id',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user, :account ] do

  user_accounts_delete(@account, params)

  blank_halt! 205
end