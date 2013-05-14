require 'rabl'

describe "Transactions" do
  before do
    valid! fixture(:user)
    sign_in
  end

  def render_resource(r, t = '/transactions/show')
    JSON.parse(Rabl::Renderer.json(r, t,
      :view_path => 'app/views',
      :locals => { tx: r })
    )
  end

  it "Retrieving yearly transies" do
    for i in 0..5 do
      month = i < 2 ? 1 : 2
      @a.deposits.create({ amount: 5, occured_on: "#{month}/06/2012".pibi_to_datetime })
    end

    rc = api_call get "/accounts/#{@account.id}/transactions/2012"
    rc.should succeed
    rc.body["transactions"].length.should == 6
  end

  scenario "Retrieving monthly transies" do
    2.times do
      @a.deposits.create({ amount: 5, occured_on: "2/06/2012".pibi_to_datetime })
    end

    4.times do
      @a.deposits.create({ amount: 5, occured_on: "3/06/2012".pibi_to_datetime })
    end

    rc = api_call get "/accounts/#{@account.id}/transactions/2012/2"
    rc.should succeed
    rc.body["transactions"].length.should == 2

    rc = api_call get "/accounts/#{@account.id}/transactions/2012/3"
    rc.should succeed
    rc.body["transactions"].length.should == 4

    rc = api_call get "/accounts/#{@account.id}/transactions?year=2012&month=3"
    rc.should succeed
    rc.body["transactions"].length.should == 4
  end

  scenario "Retrieving daily transies" do
    2.times do
      @a.deposits.create({ amount: 5, occured_on: "2/06/2012".pibi_to_datetime })
    end

    4.times do
      @a.deposits.create({ amount: 5, occured_on: "2/07/2012".pibi_to_datetime })
    end

    rc = api_call get "/accounts/#{@account.id}/transactions?year=2012&month=2&day=6"
    rc.should succeed
    rc.body["transactions"].length.should == 2

    rc = api_call get "/accounts/#{@account.id}/transactions?year=2012&month=2&day=7"
    rc.should succeed
    rc.body["transactions"].length.should == 4
  end

  scenario "Out-of-range daily transies" do
    rc = api_call get "/accounts/#{@account.id}/transactions?year=2012&month=2&day=35"
    rc.http_rc.should == 400
  end

  scenario "Out-of-range monthly transies" do
    rc = api_call get "/accounts/#{@account.id}/transactions?year=2012&month=14"
    rc.http_rc.should == 400
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
