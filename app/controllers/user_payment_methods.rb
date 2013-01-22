route_namespace '/users/:user_id/payment_methods' do
  before do
    restrict_to(:user, with: { id: params[:user_id].to_i })
  end

  get '/:id', :provides => [ :json ] do |_, pm_id|
    unless @pm = @user.payment_methods.get(pm_id.to_i)
      halt 404, 'No such payment method.'
    end

    rabl :"users/payment_methods/show"
  end

  post :provides => [ :json ] do
    p = {
      name: params[:name],
      color: params[:color],
      default: params[:default]
    }

    if params[:default]
      @user.payment_method.update({ default: false })
    end

    unless @pm = @user.payment_methods.create(p)
      halt 400, @pm.report_errors
    end

    status 204
    rabl :"users/payment_methods/show"
  end

  put '/:id', :provides => [ :json ] do |pm_id|
    # TODO: migrate from user_settings
  end

  delete '/:id', :provides => [ :json ] do |pm_id|
    unless pm = @user.payment_methods.get(pm_id.to_i)
      halt 404, "No such payment method."
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