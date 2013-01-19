route_namespace '/users/:user_id/payment_methods' do
  condition do
    restrict_to(:user, with: { id: params[:user_id].to_i })
  end

  get '/:id' do |pm_id|
    unless pm = @user.payment_methods.get(pm_id.to_i)
      halt 400, 'No such payment method.'
    end

    pm
  end

  post do
    unless pm = @user.payment_methods.create({ name: params[:payment_method][:name] })
      halt 400, pm.all_errors
    end

    200 # TODO: return the object
  end

  put '/:id' do |pm_id|
    # TODO: migrate from user_settings
  end

  delete '/:id' do |pm_id|
    unless pm = @user.payment_methods.get(pm_id.to_i)
      halt 400, "No such payment method '#{pm_id}'."
    end

    notices = []

    was_default = pm.default
    its_name    = pm.name

    if pm.destroy
      notices << "The payment method '#{its_name}' has been removed."
    else
      flash[:error] = pm.all_errors
      return redirect '/settings/preferences'
    end

    # @user = @user.refresh

    if @user.payment_methods.empty?
      @user.create_default_pm
    end

    if was_default
      @user.payment_methods.first.update!({ default: true })
      notices << "#{@user.payment_method.name} is now your default payment method."
    end

    flash[:notice] = notices

    redirect '/settings/preferences'
  end

end