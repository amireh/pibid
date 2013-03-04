route_namespace '/sessions' do

  post do
    restrict_to(:guest)

    unless u = authenticate(params[:email], params[:password])
      halt 401
    end

    authorize(u)
    @user = current_user
    rabl :"users/show"
  end

  delete auth: :user do
    session[:id] = nil
    200
  end

  get do
    if logged_in?
      200
    else
      401
    end
  end
end

# Support both GET and POST for callbacks
%w(get post).each do |method|
  send(method, "/auth/:provider/callback") do |provider|
    u, new_user = create_user_from_oauth(provider, env['omniauth.auth'])

    unless u.saved?
      halt 500, u.report_errors
    end

    # is the user logged in and attempting to link the account?
    if logged_in?

      unless u.link_to(current_user)
        halt 500, current_user.report_errors
      end

    else
      authorize(u)
    end

    200
  end
end

get '/auth/failure' do
  halt 401, "OAuth failure '#{params[:message]}'"
end
