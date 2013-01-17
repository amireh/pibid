describe "Account Transactions" do

  before do
    mockup_user
  end

  it "should reject an unknown currency" do
    t = @account.deposits.create({ amount: 5, currency: "HEH" })
    t.saved?.should be_false
    t.errors.count.should > 0
  end

  it "should create a deposit transaction" do
    @account.deposits.all.count.should == 0
    @account.deposits.create({ amount: 5 })
    @account.deposits.all.count.should == 1
  end

  it "should create a withdrawal transaction" do
    @account.withdrawals.all.count.should == 0
    @account.withdrawals.create({ amount: 5 })
    @account.withdrawals.all.count.should == 1
  end

  it "should increase the account balance" do
    @account.deposits.all.count.should == 0
    @account.balance.to_f.should == 0.0
    @account.deposits.create({ amount: 5 })
    @account.balance.to_f.should == 5.0
  end

  it "should increase the account balance" do
    @account.deposits.all.count.should == 0
    @account.balance.to_f.should == 0.0
    tx = @account.deposits.create({ amount: 5 })
    @account.balance.to_f.should == 5.0
    tx.clean?.should be_true
    @account.clean?.should be_true
    tx.update({ amount: 10 })
    @account.balance.to_f.should == 10.0
  end

  it "should decrease the account balance" do
    @account.withdrawals.all.count.should == 0
    @account.balance.to_f.should == 0.0
    @account.withdrawals.create({ amount: 5 })
    @account.balance.to_f.should == -5.0
  end

  it "should increase the account balance and respect the currency difference" do
    @account.deposits.all.count.should == 0
    @account.balance.to_f.should == 0.0
    tx = @account.deposits.create({ amount: 7.0, currency: "JOD" })
    @account.balance.to_f.should == 10.0

    tx.clean?.should be_true
    @account.clean?.should be_true

    tx.update({ currency: "USD" })
    @account.balance.to_f.should == 7.0

    tx.update({ currency: "JOD", amount: 7.0 })
    @account.balance.to_f.should == 10.0
  end

  it "should decrease the account balance and respect the currency difference" do
    @account.withdrawals.all.count.should == 0
    @account.balance.to_f.should == 0.0
    @account.withdrawals.create({ amount: 7.0, currency: "JOD" })
    @account.balance.to_f.should == -10.0
  end

  it "should deduct from the account balance and respect the currency difference" do
    @account.deposits.all.count.should == 0
    @account.balance.to_f.should == 0.0
    @account.deposits.create({ amount: 7.0, currency: "JOD" })
    @account.balance.to_f.should == 10.0
    @account.deposits.destroy
    @account.deposits.all.count.should == 0
    # @account = @account.refresh
    @account.balance.to_f.should == 0.0
  end

  it "should put back into the account balance and respect the currency difference" do
    @account.withdrawals.all.count.should == 0
    @account.balance.to_f.should == 0.0
    @account.withdrawals.create({ amount: 7.0, currency: "JOD" })
    @account.balance.to_f.should == -10.0
    @account.withdrawals.destroy
    @account.withdrawals.all.count.should == 0
    # @account = @account.refresh
    @account.balance.to_f.should == 0.0
  end

  it "should create many transactions and delete them cleanly" do
    @account.transactions.count.should == 0

    20.times do
      tx = @account.withdrawals.create({ amount: 5 })
      tx.saved?.should be_true
    end

    @account.dirty?.should be_false
    @account = @account.refresh # no idea why i have to do this here

    @account.transactions.count.should == 20
    @account.balance.to_f.should == -100.0

    @account.transactions.destroy

    @account.balance.to_f.should == 0.0
    @account.transactions.count.should == 0
  end

end