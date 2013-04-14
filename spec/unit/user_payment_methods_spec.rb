describe PaymentMethod do

  before do
    valid! fixture(:user)
  end

  it "should create a pm" do
    pm = @u.payment_methods.create({ name: 'Galaxy Coins' })
    pm.valid?.should be_true
    pm.saved?.should be_true
  end

  it "should delete a pm" do
    pm = @u.payment_methods.create({ name: 'Galaxy Coins' })
    pm.valid?.should be_true
    pm.saved?.should be_true
    @u.payment_methods.count.should == 4

    pm.destroy.should be_true
    @u = @u.refresh
    @u.payment_methods.count.should == 3

    @u.payment_methods.first.destroy.should be_true
    @u = @u.refresh
    @u.payment_methods.count.should == 2
  end

  it "should delete the last pm and create another one automatically" do
    @u.payment_methods.destroy
    @u.create_default_pm
    @u.payment_methods.count.should == 1
  end

  it "should not create a pm with a duplicate name" do
    pm = @u.payment_methods.create({ name: 'Cash' })
    pm.valid?.should be_false
    pm.saved?.should be_false
    pm.all_errors.first.should match(/already registered/)
  end

  it "should not create a pm with an empty name" do
    pm = @u.payment_methods.create({ name: '' })
    pm.valid?.should be_false
    pm.saved?.should be_false
    pm.all_errors.first.should match(/requires a name/)
  end

  it "should not allow for more than one default pm" do
    pm = @u.payment_methods.last
    pm.default.should be_false

    pm.update({ default: true }).should be_false
    pm.valid?.should be_false

    @u.payment_method.update({ default: false })
    pm.refresh.update({ default: true }).should be_true

    @u.payment_method.id.should == pm.id
    @u.payment_methods.all({default: true}).count.should == 1
    # pm.all_errors.first.should match(/already have a default/)
  end

  it "should change the default pm" do
    dpm = @u.payment_method
    dpm.update({ default: false }).should be_true
    pm = @u.payment_methods.last
    pm.default.should be_false
    pm.update({ default: true }).should be_true
  end


  it "should delete a pm and detach its transactions" do
    pm = @u.payment_method
    tx = @u.accounts.first.deposits.create({ amount: 5, payment_method: pm })

    pm.transactions.count.should == 1
    tx.payment_method.should == pm

    pm.destroy.should be_true
    @u.refresh.payment_methods.count.should == 2
    tx.refresh.payment_method.should be_false
  end

end