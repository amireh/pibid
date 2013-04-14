post '/users/:user_id/categories',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user ] do

  api_required!({
    name: nil
  })

  @category = @user.categories.create(api_params)

  unless @category.saved?
    halt 400, @category.errors
  end

  respond_with @category do |f|
    f.json { rabl :"categories/show" }
  end
end

get '/users/:user_id/categories/:category_id',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user, :category ] do

  respond_with @category do |f|
    f.json { rabl :"categories/show" }
  end
end

patch '/users/:user_id/categories/:category_id',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user, :category ] do

  api_required!({
    name: nil
  })

  unless @category.update(api_params)
    halt 400, @category.errors
  end

  respond_with @category do |f|
    f.json { rabl :"categories/show" }
  end
end

delete '/users/:user_id/categories/:category_id',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user, :category ] do

  unless @category.destroy
    halt 400, @category.errors
  end

  blank_halt!
end