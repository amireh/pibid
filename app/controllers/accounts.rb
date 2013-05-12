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

  api_optional!({
    currency: lambda { |iso|
      unless Currency[(iso || '').to_s]
        return "Unrecognized currency ISO code."
      end
    }
  })

  no_object  = params[:no_object]; params.delete(:no_object)

  unless @account.update(api_params)
    halt 400, @account.errors
  end

  blank_halt! if no_object

  respond_with @account do |f|
    f.json {
      rabl :"accounts/show"
    }
  end
end