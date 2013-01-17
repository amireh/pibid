describe Transaction do
  before do
    mockup_user
  end

  it "should reject a tx without an amount" do
    tx = @account.transactions.create({ amount: nil })
    tx.saved?.should be_false
    tx.all_errors.first.should match(/amount is missing/)
  end

  it "should reject a tx with a negative amount" do
    tx = @account.transactions.create({ amount: -1 })
    tx.saved?.should be_false
    tx.all_errors.first.should match(/greater than 0/)

    tx = @account.transactions.create({ amount: 0 })
    tx.saved?.should be_false
    tx.all_errors.first.should match(/greater than 0/)
  end

  it "should convert to account currency" do
    tx = @account.transactions.create({ amount: 10, currency: "JOD" })
    tx.__to_account_currency.should == Currency["USD"].from("JOD", tx.amount)
  end

  it "should reject a tx with an unknown currency" do
    tx = @account.transactions.create({ amount: 10, currency: "ZXC" })
    tx.saved?.should be_false
    tx.all_errors.first.should match(/Unrecognized/)
  end

end