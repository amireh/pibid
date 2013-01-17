route_namespace '/users/:user_id/notices' do

  condition do
    restrict_to(:user, with: { id: params[:user_id].to_i })
  end

  # creates a new notice of the specified type
  # accepted types:
  # => [ 'email', 'password' ]
  post '/:type' do |type|
    # was a notice already issued and another is requested?
    redispatch = params[:redispatch]

    @type       = type       # useful in the view
    @redispatch = redispatch # useful in the view

    case type
    when "email"
      if @user.email_verified?
        return erb :"/emails/already_verified"
      end

      if redispatch
        @user.notices.all({ type: 'email' }).destroy
      else # no re-dispatch requested

        # notice already sent and is pending?
        if @user.awaiting_email_verification?
          return erb :"/emails/already_dispatched"
        end
      end

      unless @n = @user.verify_email
        halt 500, "Unable to generate a verification link: #{@user.all_errors}"
      end

      dispatch_email_verification(@user) { |success, msg|
        unless success
          @user.notices.all({ type: 'email' }).destroy
          halt 500, msg
        end
      }

    when "password"
      if redispatch
        unless @n = @user.generate_temporary_password
          halt 500, "Unable to generate temporary password: #{@user.all_errors}"
        end

        dispatch_temp_password(@user) { |success, msg|
          unless success
            @user.notices.all({ type: 'password' }).destroy
            halt 500, msg
          end
        }

        flash[:notice] = "Another temporary password message has been sent to your email."
      end

    else # an unknown type
      halt 400, "Unrecognized verification parameter '#{type}'."
    end

    erb :"/emails/dispatched"
  end

  # marks the notice identified by @token as :accepted
  put '/:token' do |token|
    unless @n = @user.notices.first({ salt: token })
      halt 400, "No such verification link."
    end

    case @n.status
    when :expired
      return erb :"emails/expired"
    when :accepted
      flash[:warning] = "This verification notice seems to have been accepted earlier."
      return redirect "/settings/notifications"
    else
      @n.accept!
      case @n.type
      when 'email'
        flash[:notice] = "Your email address '#{@n.user.email}' has been verified."
        return redirect "/settings/account"
      when 'password'
        return redirect "/settings/account"
      end
    end
  end

end # namespace['/notices']