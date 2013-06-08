describe "Users" do
  before do
    fixture_wipeout
  end

  def fill_form(in_q = {}, &cb)
    q = mockup_user_params.merge(in_q)

    rc = api_call post '/users', q

    rc.should fail(400, '.*') unless in_q.empty?

    cb.call(rc) if block_given?
  end

  it "Signing up with no name" do
    fill_form({ name: '' }) do |rc|
      rc.should fail(400, 'need your name')
    end
  end

  scenario "Signing up with no email" do
    fill_form({ email: '' }) do |rc|
      rc.should fail(400, 'need your email')
    end
  end

  scenario "Signing up with an invalid email" do
    fill_form({ email: 'this is no email' }) do |rc|
      rc.should fail(400, 'look like an email')
    end
  end

  scenario "Signing up with a taken email" do
    valid! fixture(:user)

    fill_form({ email: @user.email }) do |rc|
      rc.should fail(400, 'already registered')
    end
  end

  scenario "Signing up without a password" do
    fill_form({ password: '' }) do |rc|
      rc.should fail(400, 'must provide password')
    end
  end

  scenario "Signing up with mis-matched passwords" do
    fill_form({ password: 'barfoo123' }) do |rc|
      rc.should fail(400, 'must match')
    end
  end

  scenario "Signing up with a password too short" do
    fill_form({ password: 'bar', password_confirmation: 'bar' }) do |rc|
      rc.should fail(400, 'be at least characters long')
    end
  end

  scenario "Signing up with correct info" do
    fill_form do |rc|
      rc.should succeed
    end
  end

  scenario "Reading my data" do
    valid! fixture(:user)
    sign_in @user

    rc = api_call get "/users/#{@user.id}"
    rc.should succeed

    rc.body["id"].to_i.should == @user.id
    rc.body["email"].should == @user.email
  end

  scenario "Reading someone else's data" do
    valid! fixture(:user)
    valid! fixture(:another_user)

    sign_in @user

    rc = api_call get "/users/#{@user2.id}"
    rc.should fail(403, 'do not have access')
  end

  context "OAuth" do
    before(:all) do
      OmniAuth.config.test_mode = true
    end

    def oauth_signup(provider, params = {})
      params = mockup_user_params.merge(params.merge({
        provider: provider
      }))

      OmniAuth.config.add_mock(provider.to_sym, params)
      # request.env["omniauth.auth"] = OmniAuth.config.mock_auth[provider.to_sym]

      rc = api_call post "/auth/#{provider}/callback", params

      yield rc if block_given?
    end

    def oauth_signin(provider, user)
      rc = api_call post "/auth/#{provider}/callback", { uid: user.uid, provider: provider.to_sym }

      yield rc if block_given?
    end

    scenario "Authenticating for the first time" do
      oauth_signup("developer") do |rc|
        rc.should succeed
      end
    end

    scenario "Bad auth hash" do
      oauth_signup("developer", { email: nil }) do |rc|
        rc.should fail(500, 'need your email')
      end

      oauth_signup("developer", { email: '' }) do |rc|
        rc.should fail(500, 'need your email')
      end
    end

    scenario "Signing in using a 3rd-party account" do
      oauth_signup("developer") do |rc|
        rc.should succeed

        nr_users = User.count
        nr_users.should == 2

        oauth_signup("developer") do |rc|
          rc.should succeed

          User.count.should == nr_users
        end
      end
    end

    scenario "Conflict with an existing user" do
      valid! fixture(:user)

      oauth_signup("developer", { email: @user.email }) do |rc|
        rc.should succeed

        oauth_user = User.first({ provider: "developer" })
        oauth_user.link.should be_false
      end
    end

    scenario "Linking an account" do
      valid! fixture(:user)
      sign_in @user

      oauth_signup("developer") do |rc|
        rc.should succeed

        oauth_user = User.first({ provider: "developer" })
        oauth_user.link.should == @user
      end
    end

    scenario "Signing in using a linked account" do
      valid! fixture(:user)
      sign_in @user

      oauth_signup("developer") do |rc|
        rc.should succeed

        oauth_user = User.first({ provider: "developer" })
        oauth_user.link.should == @user

        sign_out
        api { get "/sessions" }.should fail(401, "You must sign in first")

        oauth_signin("developer", oauth_user) do |rc|
          rc.should succeed

          # we need to stamp the cookie manually
          cookie = last_response.header["Set-Cookie"]
          header "Cookie", cookie

          api { get "/sessions" }.should succeed
          api { get "/users/#{@user.id}" }.should succeed
        end
      end
    end

    context "OAuth from an external referer" do
      before(:each) do
        header 'Referer', 'http://pibi.localhost'
        header 'Origin', 'http://pibi.localhost'
        header 'HTTP_REFERER', 'http://pibi.localhost'
      end

      scenario "Getting redirected after a successful sign-up" do

        oauth_signup("developer") do |rc|
          rc.should succeed(302)
        end
      end

      scenario "Getting redirected after a successful sign-in" do
        oauth_signup("developer") do |rc|
          rc.should succeed(302)

          oauth_signup("developer") do |rc|
            rc.should succeed(302)
          end
        end
      end

      scenario "Getting redirected with an error" do
        oauth_signup("developer", { email: nil, uid: nil }) do |rc|
          rc.should succeed(302)
          follow_redirect!
          last_request.url.should match(/provider_error/)
        end

        oauth_signup("developer", { email: nil, uid: nil }) do |rc|
          rc.should succeed(302)
          follow_redirect!
          last_request.url.should match(/provider_error/)
        end

      end
    end

  end

end
