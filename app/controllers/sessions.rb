route_namespace '/sessions' do

  post do
    restrict_to(:guest)

    unless u = authenticate(params[:email], params[:password])
      halt 401
    end

    authorize(u)
    200
  end

  delete do
    restrict_to(:user)

    session[:id] = nil

    flash[:notice] = "Successfully logged out."
    redirect '/'
  end
end

# Support both GET and POST for callbacks
%w(get post).each do |method|
  send(method, "/auth/:provider/callback") do |provider|
    u, new_user = create_user_from_oauth(provider, env['omniauth.auth'])

    if u.nil? || !u.saved?
      error_kind = new_user ? 'signing you up' : 'logging you in'
      halt 500,
        "Sorry! Something wrong happened while #{error_kind} using your #{provider_name provider}" +
        " account:<br /><br /> #{u.all_errors}"
    end

    # is the user logged in and attempting to link the account?
    if logged_in?
      if u.link_to(current_user)
        flash[:notice] = "Your #{provider_name(provider)} account is now linked to your #{provider_name(current_user)} one."
      else
        flash[:error] = "Linking to the #{provider_name(provider)} account failed: #{current_user.all_errors}"
      end

      return redirect back
    else
      # nope, a new user or has just logged in
      if new_user
        flash[:notice] = "Welcome to #{AppName}! You have successfully signed up using your #{provider_name(provider)} account."
      end

      # stamp the session as this new user
      authorize(u)
    end

    redirect '/'
  end
end

get '/auth/failure' do
  halt 401, "OAuth failure '#{params[:message]}'"
end