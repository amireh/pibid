require 'rabl'

feature "User payment methods" do
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
    rc = prc get "/users/#{@user.id}/categories/#{c.id}"
    rc.resp.status.should == 200
    rc.rc.should == render_resource(c)
  end

  scenario "Creating a category" do
    rc = prc post "/users/#{@user.id}/categories", { name: 'Bazooka' }
    rc.resp.status.should == 200

    c = @user.categories.first({ name: 'Bazooka' })
    rc.rc.should == render_resource(c)
  end

  scenario "Updating a category" do
    c = @user.categories.first
    rc = prc put "/users/#{@user.id}/categories/#{c.id}", { name: 'Bazooka' }
    rc.resp.status.should == 200
    c.refresh.name.should == 'Bazooka'
    rc.rc.should == render_resource(c.refresh)
  end

  scenario "Removing a category" do
    c = @user.categories.first
    rc = prc delete "/users/#{@user.id}/categories/#{c.id}"
    rc.resp.status.should == 200
    rc.rc.should == {}
  end

  scenario "Operating on a non-existing category" do
    c = @user.categories.first
    rc = prc delete "/users/#{@user.id}/categories/#{c.id}12345"
    rc.resp.status.should == 404
    rc.should fail('No such resource')
  end

end
