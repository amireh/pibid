describe AccessToken do
  before(:all) do
    valid! fixture(:user)
  end

  after do
    @user.access_tokens.destroy
  end

  it 'should be created' do
    access_token = valid! @user.access_tokens.create({
      udid: UUID.generate
    })

    access_token.digest.should_not be_empty
  end

  it 'should be unique per UDID' do
    udid = UUID.generate

    valid! @user.access_tokens.create({ udid: udid })
    invalid! @user.access_tokens.create({ udid: udid })
  end
end