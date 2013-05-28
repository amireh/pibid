helpers do
  def user_payment_methods_create(user, p = params)
    api_required!({
      name: nil
    }, p)

    api_optional!({
      color: lambda { |v|
        if v
          if v.empty?
            return "You must define some color!"
          elsif (v =~ /[\w]{6}/) == nil
            return "Color must be a hex-code color value of 6 characters"
          end
        end
      },
      default: nil
    }, p)

    last_default_pm = nil

    api_transform! :default do |v|
      if !!v
        last_default_pm = user.payment_method
      end

      v
    end

    payment_method = user.payment_methods.create(api_params)

    unless payment_method.saved?
      halt 400, payment_method.errors
    end

    if last_default_pm
      last_default_pm.update!({ default: false })
    end

    payment_method
  end

  def user_payment_methods_update(payment_method, p = params)
    api_optional!({
      name: nil,
      color: lambda { |v|
        if v
          if v.empty?
            return "You must define some color!"
          elsif (v =~ /[\w]{6}/) == nil
            return "Color must be a hex-code color value of 6 characters"
          end
        end
      },
      default: nil
    }, p)

    api_consume! :default do |value|
      if !!value
        payment_method.user.payment_method.update!({ default: false })
        payment_method.update!({ default: true })
      end
    end

    unless payment_method.update(api_params)
      halt 400, payment_method.errors
    end

    payment_method
  end

  def user_payment_methods_delete(payment_method, p = params)
    user, was_default = payment_method.user, payment_method.default

    unless payment_method.destroy
      halt 400, payment_method.errors
    end

    if user.payment_methods.empty?
      user.create_default_pm
    else
      if was_default
        user.payment_methods.first.update!({ default: true })
      end
    end

    true
  end

end

get '/users/:user_id/payment_methods',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user ] do

  @payment_methods = @user.payment_methods

  respond_with @payment_methods do |f|
    f.json { rabl :"payment_methods/index", collection: @payment_methods }
  end
end

post '/users/:user_id/payment_methods',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user ] do

  @payment_method = user_payment_methods_create(@user, params)

  respond_with @payment_method do |f|
    f.json { rabl :"payment_methods/show" }
  end
end

get '/users/:user_id/payment_methods/:payment_method_id',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user, :payment_method ] do

  respond_with @payment_method do |f|
    f.json { rabl :"payment_methods/show" }
  end
end

patch '/users/:user_id/payment_methods/:payment_method_id',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user, :payment_method ] do

  @payment_method = user_payment_methods_update(@payment_method, params)

  respond_with @payment_method do |f|
    f.json { rabl :"payment_methods/show" }
  end
end

delete '/users/:user_id/payment_methods/:payment_method_id',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user, :payment_method ] do

  user_payment_methods_delete(@payment_method, params)

  blank_halt! 205
end