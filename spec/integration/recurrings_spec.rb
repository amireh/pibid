require 'rabl'

describe "Recurrings" do
  before(:all) do
    valid! fixture(:user)
  end

  before do
    sign_in
    @account = @a = @account.refresh
    @a.recurrings.destroy
  end

  scenario "Creating a monthly recurring" do
    rc = api_call post "/accounts/#{@account.id}/recurrings", {
      amount: 5,
      note: "Salary",
      flow_type: "positive",
      frequency: "monthly",
      monthly_days: [18]
    }

    rc.should succeed
    @a.refresh.recurrings.count.should == 1
  end

  scenario "Creating a yearly recurring" do
    rc = api_call post "/accounts/#{@account.id}/recurrings", {
      amount: 5,
      note: "Salary",
      flow_type: "positive",
      frequency: "yearly",
      yearly_day: 18,
      yearly_months: [7]
    }

    rc.should succeed
    @a.refresh.recurrings.count.should == 1
  end

  scenario "Creating a yearly recurring with bad recurrence" do
    rc = api_call post "/accounts/#{@account.id}/recurrings", {
      amount: 5,
      note: "Salary",
      flow_type: "positive",
      frequency: "yearly",
      yearly_day: 18
    }

    rc.should fail(400, 'Missing :yearly_months')
  end

  scenario "Creating a weekly recurring" do
    rc = api_call post "/accounts/#{@account.id}/recurrings", {
      amount: 5,
      note: "Salary",
      flow_type: "positive",
      frequency: "weekly",
      weekly_days: [ 'tuesday' ]
    }

    rc.should succeed
  end

  scenario "Creating a monthly recurring" do
    rc = api_call post "/accounts/#{@account.id}/recurrings", {
      amount: 5,
      note: "Salary",
      flow_type: "positive",
      frequency: "monthly",
      monthly_days: [18]
    }

    rc.should succeed
  end

  scenario "Creating a monthly recurring with bad recurrence" do
    rc = api_call post "/accounts/#{@account.id}/recurrings", {
      amount: 5,
      note: "Salary",
      flow_type: "positive",
      frequency: "monthly"
    }

    rc.should fail(400, 'Missing :monthly_days')
  end

  scenario "Creating a daily recurring" do
    rc = api_call post "/accounts/#{@account.id}/recurrings", {
      amount: 5,
      note: "Salary",
      flow_type: "positive",
      frequency: "daily"
    }

    rc.should succeed
  end

  scenario "Updating a transie" do
    tx = valid! fixture(:recurring)

    rc = api_call patch "/accounts/#{@account.id}/recurrings/#{tx.id}", { amount: 10 }
    rc.should succeed

    tx.refresh.amount.should == 10
  end

  scenario "deactivating a transie" do
    tx = valid! fixture(:recurring)

    rc = api_call patch "/accounts/#{@account.id}/recurrings/#{tx.id}", { active: false }
    rc.should succeed

    tx.refresh.active?.should == false
  end

  scenario "re-activating a transie" do
    tx = valid! fixture(:recurring, { active: false })

    rc = api_call patch "/accounts/#{@account.id}/recurrings/#{tx.id}", { active: true }
    rc.should succeed

    tx.refresh.active?.should == true
  end

  context "Tagging recurries" do
    it "tagging a transie" do
      @tx = valid! fixture(:recurring)
      @c  = valid! fixture(:category)

      rc = api_call patch "/accounts/#{@account.id}/recurrings/#{@tx.id}", { categories: [ @c.id ] }
      rc.should succeed

      @tx.refresh.categories.count.should == 1
    end

    it "modifying a transie's categories" do
      @tx = valid! fixture(:recurring, { categories: @user.categories.map(&:id) })

      rc = api_call patch "/accounts/#{@account.id}/recurrings/#{@tx.id}", {
        categories: [ @user.categories.first.id ]
      }

      rc.should succeed

      @tx.refresh.categories.count.should == 1
    end

    it "wiping out all transie categories" do
      @tx = valid! fixture(:recurring, { categories: @user.categories.map(&:id) })
      @tx.refresh.categories.length.should == @user.categories.length

      api {
        patch "/accounts/#{@account.id}/recurrings/#{@tx.id}", {
          categories: [ ]
        }
      }.should succeed

      @tx.refresh.categories.count.should == 0
    end
  end

  it "destroys a transie" do
    @tx = valid! fixture(:recurring)

    rc = api_call delete "/accounts/#{@account.id}/recurrings/#{@tx.id}"
    rc.should succeed

    @account.refresh.recurrings.count.should == 0
  end

end
