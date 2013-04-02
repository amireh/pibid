route_namespace '/sessions' do

  get auth: [ :user ], provides: [ :json ] do
    rabl :"sessions/show"
  end

  post auth: [ :guest ], provides: [ :json ] do
    puts "authenticating #{params[:email]}"

    unless u = authenticate(params[:email], params[:password])
      halt 401, 'Bad credentials.'
    end

    authorize(u)

    rabl :"sessions/show"
  end

  delete auth: :user, provides: [ :json ] do
    session[:id] = nil

    halt 200, {}.to_json
  end

  delete '/:sink', auth: :user, provides: [ :json ] do
    session[:id] = nil

    halt 200, {}.to_json
  end

  get '/pulse', auth: :user do
    halt 200, {}.to_json
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