get '/sessions', auth: [ :user ], provides: [ :json ] do
  rabl :"sessions/show"
end

get '/sessions/pulse', auth: [ :user ] do
  blank_halt!
end

post '/sessions', auth: [ :guest ], provides: [ :json ] do
  unless u = authenticate(params[:email], params[:password])
    halt 401, 'Bad credentials.'
  end

  authorize(u)

  rabl :"sessions/show"
end

delete '/sessions', auth: :user, provides: [ :json ] do
  session[:id] = nil

  blank_halt!
end

delete '/sessions/:sink', auth: :user, provides: [ :json ] do
  session[:id] = nil

  blank_halt!
end

# Support both GET and POST for callbacks
%w(get post).each do |method|
  send(method, "/auth/:provider/callback") do |provider|
    origin          = env['omniauth.origin'] || env['HTTP_REFERER']
    should_redirect = !!(origin && !origin.to_s.empty?)

    begin
      unless u = user_from_oauth(provider, env['omniauth.auth'])
        if should_redirect
          return redirect "#{origin.to_s}?oauth_status=failure&oauth_message=internal_error"
        end

        halt 500, "Unable to create or locate user."
      end

      authorize(u)
    rescue SlaveCreationError, MasterCreationError, LinkingError => e
      if should_redirect
        return redirect "#{origin.to_s}?oauth_status=failure&oauth_message=provider_error"
      end

      halt 500, e.message
    end


    if should_redirect
      return redirect "#{origin.to_s}?oauth_status=success"
    end

    halt 200, '{}'
  end
end

get '/auth/failure' do
  origin          = env['omniauth.origin'] || env['HTTP_REFERER']
  should_redirect = !!(origin && !origin.to_s.empty?)

  if should_redirect
    return redirect "#{origin.to_s}?oauth_status=failure&oauth_message=provider_error"
  end

  halt 401, "OAuth failure '#{params[:message]}'"
end