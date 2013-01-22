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

  def create_or_update_pm(pm = PaymentMethod.new)
    p = accept_params([ :name, :color, :default ], pm)

    if params[:default]
      @user.payment_method.update({ default: false })
    end

    if pm.saved?
      unless pm.update(p)
        halt 400, pm.report_errors
      end
    else
      unless pm = @user.payment_methods.create(p)
        halt 400, pm.report_errors
      end
    end

    pm
  end

  post :provides => [ :json ] do
    @pm = create_or_update_pm

    rabl :"users/payment_methods/show"
  end

  put '/:id', :provides => [ :json ] do |_, pm_id|
    halt 404 unless @pm = @user.payment_methods.get(pm_id.to_i)

    create_or_update_pm(@pm)

    rabl :"users/payment_methods/show"
  end

  delete '/:id', :provides => [ :json ] do |_, pm_id|
    halt 404 unless pm = @user.payment_methods.get(pm_id.to_i)

    was_default = pm.default

    unless pm.destroy
      halt 500, pm.report_errors
    end

    if @user.payment_methods.empty?
      @user.create_default_pm
    end

    if was_default
      @user.payment_methods.first.update!({ default: true })
    end

    200
  end

end