route_namespace '/users/:user_id/settings' do
  condition do
    restrict_to(:user, with: { id: params[:user_id].to_i })
  end

  put '/preferences' do
    notices = []
    errors  = []

    # update the user's default payment method
    if params[:default_payment_method]
      pm = @user.payment_methods.get(params[:default_payment_method].to_i)
      unless pm
        halt 400, "No such payment method."
      else
        if @user.payment_method.id != params[:default_payment_method].to_i
          @user.payment_method.update({ default: false })
          if pm.update({ default: true })
            notices << "The default payment method now is '#{@user.payment_method.name}'"
          else
            halt 400
            errors << @user.all_errors
          end
        end
      end
    end

    unless @user.payment_method
      @user.payment_methods.first.update({ default: true })
    end



    # update the payment method colors
    params["pm_colors"] && params["pm_colors"].each_pair { |pm_id, color|
      pm = @user.payment_methods.get(pm_id)
      if pm && pm.color != color
        pm.update({ color: color })
      end
    }

    flash[:error]  = errors.flatten unless errors.empty?
    flash[:notice] = notices.flatten unless notices.empty?

    redirect back
  end

  post '/password' do

    pw = User.encrypt(params[:password][:current])

    if current_user.password != pw then
      flash[:error] = "The current password you've entered isn't correct!"
      return redirect back
    end

    # validate length
    # we can't do it in the model because it gets the encrypted version
    # which will always be longer than 8
    if params[:password][:new].length < 7
      flash[:error] = "That password is too short, it must be at least 7 characters long."
      return redirect back
    end

    back_url = back

    @user.password              = User.encrypt(params[:password][:new])
    @user.password_confirmation = User.encrypt(params[:password][:confirmation])

    if current_user.save then
      notices = current_user.pending_notices({ type: 'password' })
      unless notices.empty?
        back_url = "/"
        notices.each { |n| n.accept! }
      end
      flash[:notice] = "Your password has been changed."
    else
      flash[:error] = @user.all_errors
    end

    redirect back_url
  end

end


