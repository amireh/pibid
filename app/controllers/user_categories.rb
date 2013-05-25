helpers do
  def user_categories_create(p = params)
    api_required!({
      name: nil
    }, p)

    api_optional!({
      icon: nil
    }, p)

    category = @user.categories.create(api_params)

    unless category.saved?
      halt 400, category.errors
    end

    category
  end

  def user_categories_update(category = @category, p = params)
    api_optional!({
      name: nil,
      icon: nil
    }, p)

    unless category.update(api_params)
      halt 400, category.errors
    end

    category
  end

  def user_categories_delete(category = @category, p = params)
    unless category.destroy
      halt 400, category.errors
    end

    true
  end
end

post '/users/:user_id/categories',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user ] do

  @category = user_categories_create(params)

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

  @category = user_categories_update(@category, params)

  respond_with @category do |f|
    f.json { rabl :"categories/show" }
  end
end

delete '/users/:user_id/categories/:category_id',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user, :category ] do

  user_categories_delete(@category, params)

  blank_halt!
end