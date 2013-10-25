require 'rabl'

describe "Transactions" do
  before(:all) do
    valid! fixture(:user)
  end

  before do
    sign_in
    @account = @a = @account.refresh
    @a.transactions.destroy
  end

  def render_resource(r, t = '/transactions/show')
    JSON.parse(Rabl::Renderer.json(r, t,
      :view_path => 'app/views',
      :locals => { tx: r })
    )
  end

  it 'retrieving transactions from all accounts' do
    account1 = @account
    account2 = valid! fixture(:account)

    for i in 1..5 do
      valid! fixture(:deposit, {
        amount: 5,
        occured_on: Time.utc(2012, 1, i),
        account: account1
      })

      valid! fixture(:deposit, {
        amount: 5,
        occured_on: Time.utc(2012, 1, i),
        account: account2
      })

    end

    rc = api_call get "/users/#{@user.id}/transactions", {
      from: '1/1/2012',
      to: '1/6/2012'
    }

    rc.should succeed
    rc.body["transactions"].length.should == 10

    account2.destroy
  end

  it "Retrieving yearly transies" do
    for i in 0..5 do
      month = i < 2 ? 1 : 2
      @a.deposits.create({ amount: 5, occured_on: Time.utc(2012, month, 06) })
    end

    rc = api_call get "/accounts/#{@account.id}/transactions/drilldown/2012"
    rc.should succeed
    rc.body["transactions"].length.should == 6
  end

  scenario "Retrieving monthly transies" do
    2.times do
      @a.deposits.create({ amount: 5, occured_on: Time.utc(2012, 2, 06) })
    end

    4.times do
      @a.deposits.create({ amount: 5, occured_on: Time.utc(2012, 3, 06) })
    end

    rc = api_call get "/accounts/#{@account.id}/transactions/drilldown/2012/2"
    rc.should succeed
    rc.body["transactions"].length.should == 2

    rc = api_call get "/accounts/#{@account.id}/transactions/drilldown/2012/3"
    rc.should succeed
    rc.body["transactions"].length.should == 4
  end

  scenario "Retrieving daily transies" do
    2.times do
      @a.deposits.create({
        amount: 5,
        occured_on: Time.utc(2012, 2, 06)
      })
    end

    4.times do
      @a.deposits.create({
        amount: 5,
        occured_on: Time.utc(2012, 2, 07)
      })
    end

    rc = api_call get "/accounts/#{@account.id}/transactions/drilldown/2012/2/6"
    rc.should succeed
    rc.body["transactions"].length.should == 2

    rc = api_call get "/accounts/#{@account.id}/transactions/drilldown/2012/2/7"
    rc.should succeed
    rc.body["transactions"].length.should == 4
  end

  scenario "Out-of-range drilldown" do
    api { get "/accounts/#{@account.id}/transactions/drilldown/2012/2/35" }.should  fail(400, 'Invalid segment')
    api { get "/accounts/#{@account.id}/transactions/drilldown/2012/13/30" }.should fail(400, 'Invalid segment')
    api { get "/accounts/#{@account.id}/transactions/drilldown/bad" }.should        fail(400, 'Invalid segment')
    api { get "/accounts/#{@account.id}/transactions/drilldown/2012/bad" }.should   fail(400, 'Invalid segment')
    api { get "/accounts/#{@account.id}/transactions/drilldown/2012/1/bad" }.should fail(400, 'Invalid segment')
  end

  scenario "Creating a transaction" do
    @a.deposits.count.should == 0
    rc = api_call post "/accounts/#{@account.id}/transactions", { type: "deposit", amount: 5 }
    rc.should succeed
    @a.refresh.deposits.count.should == 1
  end

  scenario "Updating a transie" do
    @a.deposits.count.should == 0
    rc = api_call post "/accounts/#{@account.id}/transactions", { type: "deposit", amount: 5 }
    rc.should succeed

    tx = @a.refresh.deposits.first

    rc = api_call patch "/accounts/#{@account.id}/transactions/#{tx.id}", { amount: 10 }
    rc.should succeed

    tx.refresh.amount.should == 10
    @a.refresh.balance.should == 10
  end

  context "tagging transies" do
    it "tagging a transie" do
      @tx = valid! fixture(:deposit)
      @c  = valid! fixture(:category)

      rc = api_call patch "/accounts/#{@account.id}/transactions/#{@tx.id}", { categories: [ @c.id ] }
      rc.should succeed

      @tx.refresh.categories.count.should == 1
    end

    it "modifying a transie's categories" do
      @tx = valid! fixture(:deposit, { categories: @user.categories.map(&:id) })

      rc = api_call patch "/accounts/#{@account.id}/transactions/#{@tx.id}", {
        categories: [ @user.categories.first.id ]
      }

      rc.should succeed

      @tx.refresh.categories.count.should == 1
    end

    it "wiping out all transie categories" do
      @tx = valid! fixture(:deposit, { categories: @user.categories.map(&:id) })
      @tx.refresh.categories.length.should == @user.categories.length

      api {
        patch "/accounts/#{@account.id}/transactions/#{@tx.id}", {
          categories: [ ]
        }
      }.should succeed

      @tx.refresh.categories.count.should == 0
    end
  end

  it "destroys a transie" do
    @tx = valid! fixture(:deposit)

    rc = api_call delete "/accounts/#{@account.id}/transactions/#{@tx.id}"
    rc.should succeed

    @account.refresh.deposits.count.should == 0
  end

end
