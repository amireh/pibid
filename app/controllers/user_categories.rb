route_namespace '/users/:user_id/categories' do
  condition do
    restrict_to(:user, with: { id: params[:user_id].to_i })
  end

  get '/:id' do |cid|
    unless @c = current_user.categories.first({id: cid})
      error 404, "No such category"
    end

    erb :"categories/show"
  end

  get '/:id/edit' do |cid|
    unless @c = current_user.categories.first({id: cid})
      halt 404, "No such category"
    end

    erb :"categories/edit"
  end

  post do
    c = @user.categories.create({
      name: params["name"].to_s
    })

    if c.saved?
      flash[:notice] = "Category '#{c.name}' created."
    else
      flash[:error]  = c.all_errors
    end

    redirect back
  end

  put '/:id' do |cid|
    unless c = @user.categories.get(cid)
      halt 400, "No such category"
    end

    if c.update({ name: params[:name] })
      flash[:notice] = "Category '#{c.name}' has been updated."
    else
      flash[:error] = c.all_errors
    end

    redirect back
  end

  delete '/:id' do |cid|
    unless c = @user.categories.get(cid)
      halt 400, 'No such category'
    end

    name = c.name

    if c.destroy
      flash[:notice] = "Category '#{name}' has been removed."
    else
      flash[:error] = c.errors
    end

    redirect '/categories'
  end
end

