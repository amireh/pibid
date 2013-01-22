route_namespace '/users/:user_id/categories' do
  before do
    restrict_to(:user, with: { id: params[:user_id].to_i })
  end

  post do
    unless @c = @category = @user.categories.create({ name: params["name"].to_s })
      halt 400, @c.report_errors
    end

    rabl :"categories/show"
  end

  route_namespace '/users/:user_id/categories/:cid' do

    before do
      restrict_to(:user, with: lambda { |u|
        return false unless u.id == params[:user_id].to_i

        unless @c = @category = u.categories.get(params[:cid].to_i)
          halt 404, 'No such category.'
        end

        true
      })
    end

    get :provides => [ :json ] do
      rabl :"categories/show"
    end

    # Accepts:
    # => name: String
    put :provides => [ :json ] do

      unless @c.update({ name: params[:name] })
        halt 400, @c.report_errors
      end

      rabl :"categories/show"
    end

    delete :provides => [ :json ] do
      unless @c.destroy
        halt 500
      end

      200
    end

  end # ns: /categories/:category_id
end # ns: /categories