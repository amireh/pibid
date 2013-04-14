feature "User account settings" do
  before do
    mockup_user_params

    valid! fixture(:user)
    sign_in
  end

  scenario "Setting a valid email" do
    rc = api_call patch "/users/#{@user.id}", { email: 'me@pibibot.com' }
    rc.should succeed
    @user.refresh.email.should == 'me@pibibot.com'
  end

  scenario "Setting an invalid email" do
    rc = api_call patch "/users/#{@user.id}", { email: 'asdf' }
    rc.should fail(400, 'look like an email')
  end

  scenario "Changing the name" do
    rc = api_call patch "/users/#{@user.id}", { name: 'fubar' }
    rc.should succeed
    @user.refresh.name.should == 'fubar'
  end

  scenario "Setting an empty name" do
    rc = api_call patch "/users/#{@user.id}", { name: '' }
    rc.should fail(400, 'need your name')
  end

  scenario "Changing the password" do
    rc = api_call patch "/users/#{@user.id}", {
      :current_password => Fixtures::UserFixture.password,
      :password     => 'foobar123',
      :password_confirmation => 'foobar123'
    }

    # rc.should fail(400, 'need your name')
    rc.should succeed
    @user.refresh.password.should == User.encrypt('foobar123')
  end

  scenario "Changing the password with an invalid current one" do
    rc = api_call patch "/users/#{@user.id}", {
      :current_password => 'moo',
      :password     => 'foobar123',
      :password_confirmation => 'foobar123'
    }

    rc.should fail(400, 'current is wrong')
  end

  scenario "Changing the password with an invalid confirmation" do
    rc = api_call patch "/users/#{@user.id}", {
      :current_password => Fixtures::UserFixture.password,
      :password     => 'foobar123',
      :password_confirmation => 'foobar123zxc'
    }

    rc.should fail(400, 'must match')
  end

  scenario "Changing the password with a short one" do
    rc = api_call patch "/users/#{@user.id}", {
      :current_password => Fixtures::UserFixture.password,
      :password     => 'asdf',
      :password_confirmation => 'asdf'
    }

    rc.should fail(400, 'too short')
  end

end
