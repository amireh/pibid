describe AccessToken do
  before(:all) do
    valid! fixture(:user)
  end

  after do
    @user.access_tokens.destroy
  end

  scenario 'I request an access token' do
    sign_in

    rc = api_call post "/access_tokens", {
      udid: UUID.generate
    }
    rc.should succeed(200)
    rc.body['digest'].should be_true
  end

  scenario 'I try to issue an access token, but I\'m not authorized' do
    rc = api_call post '/access_tokens', { udid: UUID.generate }
    rc.should fail(401, 'must sign in first')
  end

  scenario 'I try to issue an access token, but one has already been issued' do
    sign_in

    udid = UUID.generate

    rc = api_call post "/access_tokens", { udid: udid }
    rc.should succeed(200)

    token = rc.body['digest']
    token.should_not be_empty

    rc = api_call post "/access_tokens", { udid: udid }
    rc.should succeed(200)

    rc.body['digest'].should == token
  end

  scenario 'I login using an access token' do
    sign_in
    rc = api_call post "/access_tokens", { udid: UUID.generate }
    rc.should succeed(200)

    token = rc.body['digest']
    sign_out

    expect { api_call get '/sessions/pulse' }.to fail(401, '.*')
    expect { api_call put "/access_tokens/#{token}" }.to succeed
    expect { api_call get '/sessions/pulse' }.to succeed
  end
end