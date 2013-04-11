get '/users/:user_id/accounts/:account_id',
  auth: :user,
  provides: [ :json ],
  requires: [ :user, :account ] do

  rabl :"accounts/show"
end