route_namespace '/users/:user_id/notices' do

  before do
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
        halt 500, "Unable to generate a verification link: #{@user.report_errors}"
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
          halt 500, "Unable to generate temporary password: #{@user.report_errors}"
        end

        dispatch_temp_password(@user) { |success, msg|
          unless success
            @user.notices.all({ type: 'password' }).destroy
            halt 500, msg
          end
        }

        200
      end

    else # an unknown type
      halt 400, "Unrecognized verification parameter '#{type}'."
    end

    200
  end

  # marks the notice identified by @token as :accepted
  put '/:token' do |token|
    unless @n = @user.notices.first({ salt: token })
      halt 404, "No such verification link."
    end

    case @n.status
    when :expired
      halt 400, 'Expired.'
    when :accepted
      halt 400, 'Already accepted.'
    else
      @n.accept!
      # case @n.type
      # when 'email'
      # when 'password'
      # end
    end

    200
  end

end # namespace['/notices']