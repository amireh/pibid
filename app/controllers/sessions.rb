[ '/sessions', '/sessions/:sink' ].each do |r|
  get r, auth: [ :user ], provides: [ :json ] do
    rabl :"sessions/show"
  end

  post r, provides: [ :json ] do
    unless logged_in?
      api_required!({
        email: lambda { |v|
          if !v || v.to_s.empty? || !is_email?(v)
            return "Please enter a valid email address."
          end
        },

        password: lambda { |v|
          if !v || v.to_s.length < User::MinPasswordLength
            return "The password you entered does not seem to be correct."
          end
        }
      })


      unless u = authenticate(api_param(:email), api_param(:password))
        u = User.new
        u.errors.add :email, 'The email or password you entered were incorrect.'
        halt 400, u.errors
      end

      authorize(u)
    end

    respond_to do |f|
      f.json {
        rabl :"sessions/show"
      }
    end
  end

  delete r, provides: [ :json ] do
    session.clear

    if !logged_in?
      return blank_halt! 200
    end

    session[:id] = nil

    blank_halt! 200
  end
end

get '/sessions/pulse', auth: [ :user ] do
  blank_halt! 200
end


# Support both GET and POST for callbacks
[ 'get', 'post' ].each do |method|
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