require 'rabl'

feature "Categories" do
  before do
    mockup_user && sign_in
  end

  def render_resource(r)
    JSON.parse(Rabl::Renderer.json(r, '/categories/show',
      :view_path => 'app/views',
      :locals => { category: r, user: r.user })
    )
  end

  scenario "Retrieving a category" do
    c = @user.categories.first
    rc = api_call get "/users/#{@user.id}/categories/#{c.id}"
    rc.should succeed
    rc.body.should == render_resource(c)
  end

  scenario "Creating a category" do
    rc = api_call post "/users/#{@user.id}/categories", { name: 'Bazooka' }
    rc.should succeed

    c = @user.categories.first({ name: 'Bazooka' })
    rc.body.should == render_resource(c)
  end

  scenario "Updating a category" do
    c = @user.categories.first
    rc = api_call patch "/users/#{@user.id}/categories/#{c.id}", { name: 'Bazooka' }
    rc.should succeed
    c.refresh.name.should == 'Bazooka'
    rc.body.should == render_resource(c.refresh)
  end

  scenario "Removing a category" do
    c = @user.categories.first
    rc = api_call delete "/users/#{@user.id}/categories/#{c.id}"
    rc.should succeed
    rc.body.should == {}
  end

  scenario "Operating on a non-existing category" do
    c = @user.categories.first
    rc = api_call delete "/users/#{@user.id}/categories/#{c.id}12345"
    rc.should fail(404, 'No such resource')
  end

end
