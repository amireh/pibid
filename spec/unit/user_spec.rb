describe User do

  before do
    User.destroy
    User.count.should == 0
  end

  def mock_params()
    @some_salt = Pibi.tiny_salt
    {
      name: 'Mysterious Mocker',
      email: 'very@mysterious.com',
      provider: 'pibi',
      password:               @some_salt,
      password_confirmation:  @some_salt
    }
  end

  def mock_password(salt)
    { password: salt, password_confirmation: salt }
  end

  it "should create a user" do
    u = User.create(mock_params)

    puts u.all_errors

    u.valid?.should be_true
    u.saved?.should be_true
  end

  it "should create a user with a default account and payment method" do
    u = User.create(mock_params)

    u.valid?.should be_true
    u.saved?.should be_true
    u.accounts.count.should == 1

    # Cash, Cheque, and Credit Card
    u.payment_methods.count.should == 3

    # default payment method
    u.payment_method.should be_true
  end

  it "should not create a user because of password length" do
    u = User.new(mock_params.merge(mock_password('foo')))
    u.valid?.should be_false
    u.all_errors.first.should match(/must be at least/)

    u.save.should be_false

    u = User.create(mock_params.merge(mock_password('foo')))
    u.saved?.should be_false
  end

  it "should not create a user because of password mismatch" do
    u = User.new(mock_params.merge({ password: 'foobar123' }))
    u.valid?.should be_false
    u.all_errors.first.should match(/must match/)

    u.save.should be_false
  end

  it "should not create a user because of missing password" do
    u = User.new(mock_params.merge({ password: '', password_confirmation: '' }))
    u.valid?.should be_false
    u.all_errors.first.should match(/must provide/)

    u.save.should be_false
  end

  it "should not create a user because of missing email" do
    u = User.new(mock_params.merge({ email: '' }))
    u.valid?.should be_false
    u.all_errors.first.should match(/need your email/)

    u.save.should be_false
  end

  it "should not create a user because of invalid email" do
    u = User.new(mock_params.merge({ email: 'domdom@baz' }))
    u.valid?.should be_false
    u.all_errors.first.should match(/look like an email/)

    u.save.should be_false
  end

  it "should not create a user because of unavailable email" do
    u = User.create(mock_params)
    u.saved?.should be_true

    u = User.create(mock_params)
    u.saved?.should be_false
    u.all_errors.first.should match(/already.*registered/)
  end

  it "should create a user with a registered email within a different provider scope" do
    u = User.create(mock_params)
    u.saved?.should be_true

    u = User.create(mock_params.merge({ provider: 'facebook' }))
    u.valid?.should be_true
    u.saved?.should be_true
  end

  it "should not create a user because of missing name" do
    u = User.new(mock_params.merge({name: ''}))
    u.valid?.should be_false
    u.all_errors.first.should match(/need your name/)

    u.save.should be_false
  end

  it "should link a user account to a master one" do
    master = User.create(mock_params)
    puts master.all_errors
    master.saved?.should be_true

    slave = User.create(mock_params.merge({ provider: 'facebook' }))
    slave.saved?.should be_true

    slave.link.should be_false
    slave.linked_to?(master).should be_false

    slave.link_to(master)
    slave.linked_to?(master).should be_true
    master.linked_to?(slave).should be_true
  end

  it "should link a user account and its linked slaves to a master one" do
    master = User.create(mock_params)
    master.saved?.should be_true

    slave = User.create(mock_params.merge({ provider: 'facebook' }))
    slave.saved?.should be_true

    distant_slave = User.create(mock_params.merge({ provider: 'github' }))
    distant_slave.saved?.should be_true

    distant_slave.link_to(slave).should be_true
    distant_slave.linked_to?(slave).should be_true

    # link the slave to the master
    slave.linked_to?(master).should be_false
    slave.link_to(master).should be_true
    slave.linked_to?(master).should be_true

    # distant slave should be linked to the master now too
    distant_slave.linked_to?(master).should be_true
    distant_slave.linked_to?(slave).should be_false

    # master should be linked to both
    master.linked_to?(slave).should be_true
    master.linked_to?(distant_slave).should be_true
  end

end