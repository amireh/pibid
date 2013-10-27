describe "Accounts" do
  before(:all) do
    valid! fixture(:user)
  end

  before do
    sign_in
    @account = @a = @account.refresh
  end

  scenario "Purging an account" do
    rc = api_call post "/accounts/#{@account.id}/transactions", { type: "deposit", amount: 5 }
    rc.should succeed
    @a = @a.refresh
    @a.deposits.count.should == 1
    @a.balance.should == 5

    rc = api_call post "/accounts/#{@account.id}/transactions", { type: "deposit", amount: 7 }
    rc.should succeed
    @a = @a.refresh
    @a.deposits.count.should == 2
    @a.balance.should == 12

    rc = api_call post "/accounts/#{@account.id}/recurrings", {
      amount: 5,
      note: "Salary",
      flow_type: "positive",
      frequency: "monthly",
      monthly_days: [18]
    }
    rc.should succeed
    @a = @a.refresh
    @a.recurrings.count.should == 1

    rc = api_call post "/accounts/#{@account.id}/recurrings", {
      amount: 5,
      note: "Salary",
      flow_type: "positive",
      frequency: "yearly",
      yearly_day: 18,
      yearly_months: [7]
    }
    rc.should succeed
    @a = @a.refresh
    @a.recurrings.count.should == 2

    rc = api_call put "/users/#{@account.user.id}/accounts/#{@account.id}/purge", {}
    rc.should succeed
    @a = @a.refresh
    @a.transactions.count.should == 0
    @a.recurrings.count.should == 0
    @a.balance.should == 0
  end
end
