describe Transaction do
  before(:all) do
    valid! fixture(:user)

    class Transaction
      public :to_account_currency
    end
  end

  after(:all) do
    class Transaction
      protected :to_account_currency
    end
  end

  it "should reject a tx without an amount" do
    tx = @account.transactions.create({ amount: nil })
    tx.saved?.should be_false
    tx.all_errors.first.should match(/amount is missing/)
  end

  it "should reject a tx with a negative amount" do
    tx = @account.transactions.create({ amount: -1 })
    tx.saved?.should be_false
    tx.all_errors.first.should match(/must be/)

    tx = @account.transactions.create({ amount: 0 })
    tx.saved?.should be_false
    tx.all_errors.first.should match(/must be/)
  end

  it "should convert to account currency" do
    tx = @account.transactions.create({ amount: 10, currency: "JOD" })
    tx.to_account_currency.should == Currency["USD"].from("JOD", tx.amount)
  end

  it "should reject a tx with an unknown currency" do
    tx = @account.transactions.create({ amount: 10, currency: "ZXC" })
    tx.saved?.should be_false
    tx.all_errors.first.should match(/Unrecognized/)
  end

  it "should enforce the occurrence resolution to years, months, and days" do
    def test(tx)
      tx.occured_on.year.should_not == 0
      tx.occured_on.month.should_not == 0
      tx.occured_on.day.should_not == 0

      tx.occured_on.hour.should == 0
      tx.occured_on.minute.should == 0
      tx.occured_on.second == 0
    end

    now = DateTime.now

    test(Transaction.new)
    test(Transaction.new({ occured_on: DateTime.new(now.year, 1, 5, 23, 11, 34)}))
    test(Transaction.new({ occured_on: DateTime.new(now.year, 1, 5, 23, 11)}))
    test(Transaction.new({ occured_on: DateTime.new(now.year, 1, 5, 23)}))
    test(valid! fixture(:deposit))
    test(valid! fixture(:deposit, { occured_on: DateTime.new(now.year, 1, 5, 23, 11, 34)}))
    test(valid! fixture(:deposit, { occured_on: DateTime.new(now.year, 1, 5, 23, 11)}))
    test(valid! fixture(:deposit, { occured_on: DateTime.new(now.year, 1, 5, 23)}))
  end
end