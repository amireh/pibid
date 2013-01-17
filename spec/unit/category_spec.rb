describe Category do

  before do
    CategoryTransaction.destroy
    mockup_user()
    # initial category count
    @icc = @user.categories.count
  end

  it "should create a category" do
    @user.categories.count.should == @icc
    c = @user.categories.create({ name: "Utility XYZ" })
    c.errors.size.should == 0
    c.saved?.should be_true
    @user.categories.count.should == @icc+1
  end

  it "should reject a nameless category" do
    @user.categories.count.should == @icc
    c = @user.categories.create({ name: "" })
    c.valid?.should be_false
    c.saved?.should be_false
    c.all_errors.first.should match(/must provide a name/)
  end

  it "should reject a duplicate named category" do
    @user.categories.count.should == @icc
    c = @user.categories.create({ name: "Utility XYZ" })
    c.valid?.should be_true
    c.saved?.should be_true

    c = @user.categories.create({ name: "Utility XYZ" })
    c.valid?.should be_false
    c.saved?.should be_false

    c.all_errors.first.should match(/already have such a category/)
  end

  it "should attach a category to a tx" do
    @user.categories.count.should == @icc
    c = @user.categories.create({ name: "Utility XYZ" })
    c.saved?.should be_true
    @user.categories.count.should == @icc+1

    t = @account.deposits.create({ amount: 5 })
    t.saved?.should be_true

    t.categories << c
    t.save

    c.refresh.transactions.count.should == 1
  end

  it "should detach a tx from a category" do
    @user.categories.count.should == @icc
    c = @user.categories.create({ name: "Utility XYZ" })
    c.saved?.should be_true
    @user.categories.count.should == @icc+1

    t = @account.deposits.create({ amount: 5 })
    t.saved?.should be_true

    t.categories << c
    t.save

    c = c.refresh
    c.transactions.count.should == 1
    CategoryTransaction.all.count.should == 1

    c.destroy.should be_true

    CategoryTransaction.all.count.should == 0

    t = t.refresh
    t.should be_true
    t.categories.count.should == 0

    Category.count.should == @icc
    Transaction.all.count.should == 1
  end

  it "should attach many transies to a category" do
    # create a category
    @user.categories.count.should == @icc
    c = @user.categories.create({ name: "Utility XYZ" })
    c.saved?.should be_true
    @user.categories.count.should == @icc+1

    # create a couple of txes
    t = @account.deposits.create({ amount: 5 })
    t.saved?.should be_true
    t.categories << c
    t.save.should be_true
    c.transactions.all.count.should == 1
    t.categories.count.should       == 1

    t = @account.withdrawals.create({ amount: 5})
    t.saved?.should be_true
    t.categories << c
    t.save

    c.transactions.all.count.should == 2
    CategoryTransaction.all.count.should == 2
    c.destroy
    CategoryTransaction.all.count.should == 0
    Transaction.all.count.should == 2
    Category.all.count.should == @icc
  end

end
