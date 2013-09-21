get '/sessions/pulse', auth: [ :user ] do
  blank_halt! 200
end

[ '/sessions', '/sessions/:sink' ].each do |r|
  get r, auth: [ :user ], provides: [ :json ] do
    rabl :"sessions/show"
  end

  post r, provides: [ :json ] do
    unless logged_in?
      puts "logging in with #{params.inspect}" if ENV['DEBUG']

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
        halt 401, u.errors
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

# Support both GET and POST for callbacks

helpers do
  OriginExtractor = /^(https?\:\/\/)?([(\w+\.?)]+)/

  def extract_origin(uri)
    uri =~ OriginExtractor
    ([ $1 || 'http', $2 ].join('') + '/').gsub(/\/\/$/, '/')
  end
end

[ 'get', 'post' ].each do |method|
  send(method, "/auth/:provider/callback") do |provider|
    origin          = env['omniauth.origin'] || env['HTTP_REFERER']
    should_redirect = !!(origin && !origin.to_s.empty?)

    if should_redirect
      origin = extract_origin(origin)
    end

    begin
      unless u = user_from_oauth(provider, env['omniauth.auth'])
        if should_redirect
          return redirect "#{origin.to_s}/oauth/failure/#{provider}/internal_error"
        end

        halt 500, "Unable to create or locate user."
      end

      authorize(u)
    rescue SlaveCreationError, MasterCreationError, LinkingError => e
      if should_redirect
        return redirect "#{origin.to_s}/oauth/failure/#{provider}/provider_error"
      end

      halt 500, e.message
    end


    if should_redirect
      return redirect "#{origin.to_s}/oauth/success/#{provider}"
    end

    halt 200, '{}'
  end
end

get '/auth/failure' do
  origin          = params[:origin] || env['omniauth.origin'] || env['HTTP_REFERER']
  should_redirect = !!(origin && !origin.to_s.empty?)

  if should_redirect
    origin = extract_origin(origin)
  end

  provider = params[:strategy] || env['omniauth.strategy'].name

  if should_redirect
    return redirect "#{origin.to_s}/oauth/failure/#{provider}/provider_error"
  end

  halt 401, "OAuth failure '#{params[:message]}'"
end