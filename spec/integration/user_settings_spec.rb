feature "User account settings" do
  before do
    mockup_user && sign_in
  end

  scenario "Setting a valid email" do
    rc = prc put "/users/#{@user.id}", { email: 'me@pibibot.com' }
    rc.resp.status.should == 200
    @user.refresh.email.should == 'me@pibibot.com'
  end

  scenario "Setting an invalid email" do
    rc = prc put "/users/#{@user.id}", { email: 'asdf' }
    rc.should fail('look like an email')

    @user.refresh.email.should == @mockup_user_params[:email]
  end

  scenario "Changing the name" do
    rc = prc put "/users/#{@user.id}", { name: 'fubar' }
    rc.resp.status.should == 200
    @user.refresh.name.should == 'fubar'
  end

  scenario "Setting an empty name" do
    rc = prc put "/users/#{@user.id}", { name: '' }
    rc.should fail('need your name')
    @user.refresh.name.should == @mockup_user_params[:name]
  end

  scenario "Changing the password" do
    rc = prc put "/users/#{@user.id}", {
      password: {
        :current => @some_salt,
        :new     => 'foobar123',
        :confirmation => 'foobar123'
      }
    }

    # rc.should fail('need your name')
    rc.resp.status.should == 200
    @user.refresh.password.should == User.encrypt('foobar123')
  end

  scenario "Changing the password with an invalid current one" do
    rc = prc put "/users/#{@user.id}", {
      password: {
        :current => 'moo',
        :new     => 'foobar123',
        :confirmation => 'foobar123'
      }
    }

    rc.should fail('Invalid current')
  end

  scenario "Changing the password with an invalid confirmation" do
    rc = prc put "/users/#{@user.id}", {
      password: {
        :current => @some_salt,
        :new     => 'foobar123',
        :confirmation => 'foobar123zxc'
      }
    }

    rc.should fail('must match')
  end

  scenario "Changing the password with a short one" do
    rc = prc put "/users/#{@user.id}", {
      password: {
        :current => @some_salt,
        :new     => 'asdf',
        :confirmation => 'asdf'
      }
    }

    rc.should fail('too short')
  end

end
