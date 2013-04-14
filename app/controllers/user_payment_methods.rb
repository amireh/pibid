post '/users/:user_id/payment_methods',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user ] do

  api_required!({
    name: nil
  })

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
  })

  last_default_pm = nil

  api_transform! :default do |v|
    if (!!v) == true
      last_default_pm = @user.payment_method
    end

    v
  end

  @payment_method = @user.payment_methods.create(api_params)

  unless @payment_method.saved?
    halt 400, @payment_method.errors
  end

  if last_default_pm
    last_default_pm.update!({ default: false })
  end

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
  })

  api_consume! :default do |value|
    if (!!value) == true
      @user.payment_method.update({ default: false })

      @payment_method.update({ default: true })
    end
  end

  unless @payment_method.update(api_params)
    halt 400, @payment_method.errors
  end

  respond_with @payment_method do |f|
    f.json { rabl :"payment_methods/show" }
  end
end

delete '/users/:user_id/payment_methods/:payment_method_id',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user, :payment_method ] do

  was_default = @payment_method.default

  unless @payment_method.destroy
    halt 400, @payment_method.errors
  end

  if @user.payment_methods.empty?
    @user.create_default_pm
  end

  if was_default
    @user.payment_methods.first.update!({ default: true })
  end

  blank_halt!
end