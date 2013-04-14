require 'rabl'

feature "Payment methods" do
  before do
    mockup_user && sign_in
  end

  def render_resource(r, template, locals)
    JSON.parse(Rabl::Renderer.json(r, template, :view_path => 'app/views', :locals => locals))
  end

  scenario "Retrieving a payment method" do
    pm = @user.payment_method
    rc = api_call get "/users/#{@user.id}/payment_methods/#{pm.id}"
    rc.should succeed
    rc.body.should == render_resource(pm, '/payment_methods/show', { pm: pm, user: @user })
  end

  scenario "Creating a PM" do
    rc = api_call post "/users/#{@user.id}/payment_methods", { name: 'Bazooka' }
    rc.should succeed
    pm = @user.payment_methods({ name: 'Bazooka' }).first
    rc.body.should == render_resource(pm, '/payment_methods/show', { pm: pm, user: @user })
  end

  scenario "Updating a PM" do
    pm = @user.payment_method
    rc = api_call patch "/users/#{@user.id}/payment_methods/#{pm.id}", { name: 'Bazooka' }
    rc.should succeed
    rc.body["payment_method"]["name"].should == 'Bazooka'
  end

  scenario "Changing the default PM" do
    pm = @user.payment_method
    new_pm = @user.payment_methods.last

    rc = api_call patch "/users/#{@user.id}/payment_methods/#{new_pm.id}", { default: true }
    rc.should succeed

    pm.refresh.default.should be_false
    new_pm.refresh.default.should be_true
    @user.refresh.payment_method.id.should == new_pm.id
  end

  scenario "Deleting a PM" do
    pm = @user.payment_methods.last
    pm_count = @user.payment_methods.count
    rc = api_call delete "/users/#{@user.id}/payment_methods/#{pm.id}"
    rc.should succeed

    @user.refresh.payment_methods.count.should == pm_count - 1
  end

  scenario "Deleting a default PM" do
    pm = @user.payment_method
    pm_count = @user.payment_methods.count
    rc = api_call delete "/users/#{@user.id}/payment_methods/#{pm.id}"
    rc.should succeed

    @user.refresh.payment_methods.count.should == pm_count - 1
  end

end
