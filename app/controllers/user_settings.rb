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

end


