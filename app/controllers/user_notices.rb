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

  case type
  when "email"
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
    settings.comlink.broadcast({
      id: "notices.#{type}",
      client_id: @user.id,
      data: {
        user: {
          email: @user.email,
          name:  @user.name
        },
        notice: JSON.parse(rabl(:"users/notices/show", object: @notice))
      }
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