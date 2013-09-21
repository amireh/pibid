post '/access_tokens', auth: [ :user ], provides: [ :json ] do
  api_required!({
    udid: nil
  })

  @access_token = current_user.access_tokens.first_or_create({
    udid: api_param(:udid)
  })

  authorize(@access_token.user)

  respond_with @access_token do |f|
    f.json do
      rabl :"access_tokens/show"
    end
  end
end

put '/access_tokens/:digest', provides: [ :json ] do |digest|
  halt 403 if logged_in?

  unless @access_token = AccessToken.first({ digest: digest })
    halt 401
  end

  authorize(@access_token.user)

  respond_with session do |f|
    f.json do
      rabl :"sessions/show"
    end
  end
end

delete '/access_tokens/:udid', auth: [ :user ], provides: [ :json ] do |udid|
  unless @access_token = current_user.access_tokens.first({ udid: udid })
    halt 404
  end

  @access_token.destroy

  blank_halt! 200
end