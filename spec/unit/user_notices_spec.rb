describe Notice do

  before do
    User.destroy

    @some_salt = Pibi.salt
    @u = User.create({
      name: 'Mysterious Mocker',
      email: 'very@mysterious.com',
      provider: 'pibi',
      password: @some_salt,
      password_confirmation: @some_salt
    })
  end

  it "should generate an email verification notice on user creation" do
    @u.email_verified.should == false
    @u.pending_notices.count.should == 1
    @u.pending_notices.first.type.should == 'email'
    @u.pending_notices.first.data.should == @u.email
  end

  it "should update the email verification status when the notice is accepted" do
    @u.email_verified.should == false
    @u.pending_notices.first.accept!
    @u.email_verified.should == true
    @u.pending_notices.count.should == 0
  end

  it "should reset the email verification status when the email address is updated" do
    @u.email_verified.should == false
    @u.pending_notices.first.accept!
    @u.email_verified.should == true

    # try with Resource#update
    @u.update({ email: 'more@mysterious.com' }).should be_true
    @u.saved?.should be_true
    @u.email_verified.should == false

    # try with Resource#save
    @u.pending_notices.first.accept!
    @u.email_verified.should == true
    @u.email = 'very@mysterious.com'
    @u.save.should be_true
    @u.email_verified.should == false
  end

  it "should generate a user temporary password notice" do
    @u.auto_password.should == false
    pnc = @u.pending_notices.count

    @u.generate_temporary_password
    @u.auto_password.should == true
    @u.pending_notices.count.should == pnc+1
  end

end