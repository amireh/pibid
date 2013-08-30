# creates a new notice of the specified type
# accepted types:
# => [ 'email', 'password' ]
post '/users/:user_id/notices/:type',
  auth: [ :user ],
  requires: [ :user ],
  provides: [ :json ] do |user_id, type|

  api_optional!({
    redispatch: nil
  })

  # was a notice already issued and another is requested?
  redispatch = api_param(:redispatch)
  job_id = ''
  case type
  when "email"
    job_id = 'confirm_account'
    if @user.email_verified?
      halt 400, 'Already verified.'
    end

    if redispatch
      @user.notices.all({ type: 'email' }).destroy
    else # no re-dispatch requested
      # notice already sent and is pending?
      if @user.awaiting_email_verification?
        halt 400, 'Already dispatched.'
      end
    end

    unless @n = @user.verify_email
      halt 500, @user.errors
    end
  when "password"
    job_id = 'reset_password'
    if redispatch || @user.notices.all({ type: 'password' }).empty?
      unless @n = @user.generate_temporary_password
        halt 500, @user.errors
      end
    end
  else # an unknown type
    halt 400, "Unrecognized verification parameter '#{type}'."
  end

  @notice = @n

  if @n
    comlink.queue('mails', job_id, {
      client_id: @user.id,
      user: JSON.parse(rabl(:"users/show.min", object: @user)),
      notice: JSON.parse(rabl(:"users/notices/show", object: @notice))
    })
  end

  respond_with @notice do |f|
    f.json { rabl :"users/notices/show", object: @notice }
  end
end

# marks the notice identified by @token as :accepted
put '/users/:user_id/notices/:type/:token',
  auth: [ :user ],
  requires: [ :user ],
  provides: [ :json ] do |user_id, type, token|

  unless @n = @user.notices.first({ type: type, salt: token })
    halt 404, "No such verification link."
  end

  case @n.status
  when :expired
    @n.errors.add :status, 'This notification has expired.'
  when :accepted
    @n.errors.add :status, 'You have already accepted this notification.'
  else
    @n.accept!
  end

  halt 400, @n.errors unless @n.errors.empty?

  respond_to do |f|
    f.json {
      halt 200, '{}'
    }
  end
end

post '/users/reset_password', provides: [ :json ] do

  if logged_in?
    @user = current_user
  else
    api_required!({
      email: nil
    })

    unless @user = User.first({ email: api_param(:email) })
      halt 400, "No account was found registered to the email address '#{api_param(:email)}'."
    end
  end

  @user.notices.all({ type: 'password' }).destroy

  unless @notice = @user.generate_temporary_password
    halt 500, @user.errors
  end

  comlink.queue('mails', "reset_password", {
    client_id: @user.id,
    user: JSON.parse(rabl(:"users/show.min", object: @user)),
    notice: JSON.parse(rabl(:"users/notices/show", object: @notice))
  })

  respond_to do |f|
    f.json { '{}' }
  end
end

put '/users/reset_password/:token', provides: [ :json ] do |token|

  api_required!({
    current:  nil,
    password: nil,
    password_confirmation: nil
  })

  unless @notice = Notice.first({ salt: token, data: api_param(:current) })
    halt 400, "The temporary password you provided does not appear to be valid."
  end

  @user = @notice.user

  api_consume!(:current)

  unless @user.update(api_params)
    halt 400, @user.errors
  end

  authorize(@user) unless logged_in?

  respond_to do |f|
    f.json { '{}' }
  end
end

