require 'rabl'

feature "Transactions" do
  before do
    mockup_user && sign_in
  end

  def render_resource(r, t = '/transactions/show')
    JSON.parse(Rabl::Renderer.json(r, t,
      :view_path => 'app/views',
      :locals => { tx: r })
    )
  end

  scenario "Retrieving yearly transies" do
    for i in 0..5 do
      month = i < 2 ? 1 : 2
      @a.deposits.create({ amount: 5, occured_on: "#{month}/06/2012".to_date })
    end

    rc = prc get "/transactions?year=2012"
    rc.resp.status.should == 200
    rc.rc.length.should == 2
    rc.rc["1"]["transactions"].length.should == 2
    rc.rc["2"]["transactions"].length.should == 4
  end

  scenario "Retrieving monthly transies" do
    2.times do
      @a.deposits.create({ amount: 5, occured_on: "2/06/2012".to_date })
    end

    4.times do
      @a.deposits.create({ amount: 5, occured_on: "3/06/2012".to_date })
    end

    rc = prc get "/transactions?year=2012&month=2"
    rc.resp.status.should == 200
    rc.rc["6"]["transactions"].length.should == 2

    rc = prc get "/transactions?year=2012&month=3"
    rc.resp.status.should == 200
    rc.rc["6"]["transactions"].length.should == 4
  end

  scenario "Retrieving daily transies" do
    2.times do
      @a.deposits.create({ amount: 5, occured_on: "2/06/2012".to_date })
    end

    4.times do
      @a.deposits.create({ amount: 5, occured_on: "2/07/2012".to_date })
    end

    rc = prc get "/transactions?year=2012&month=2&day=6"
    rc.resp.status.should == 200
    rc.rc["transactions"].length.should == 2

    rc = prc get "/transactions?year=2012&month=2&day=7"
    rc.resp.status.should == 200
    rc.rc["transactions"].length.should == 4
  end

  scenario "Out-of-range daily transies" do
    rc = prc get "/transactions?year=2012&month=2&day=35"
    rc.resp.status.should == 400
  end

  scenario "Out-of-range monthly transies" do
    rc = prc get "/transactions?year=2012&month=14"
    rc.resp.status.should == 400
  end

  scenario "Creating a transaction" do
    @a.deposits.count.should == 0
    rc = prc post "/deposits", { amount: 5 }
    rc.resp.status.should == 200
    @a.refresh.deposits.count.should == 1
  end

  scenario "Updating a transie" do
    @a.deposits.count.should == 0
    rc = prc post "/deposits", { amount: 5 }
    rc.resp.status.should == 200

    tx = @a.refresh.deposits.first

    rc = prc put "/deposits/#{tx.id}", { amount: 10 }
    rc.resp.status.should == 200

    tx.refresh.amount.should == 10
    @a.refresh.balance.should == 10
  end

  scenario "Attaching a category to a transie" do
    @a.deposits.count.should == 0
    rc = prc post "/deposits", { amount: 5 }
    rc.resp.status.should == 200

    tx = @a.refresh.deposits.first

    rc = prc put "/deposits/#{tx.id}", { categories: [ @user.categories.first.id ] }
    rc.resp.status.should == 200

    tx.refresh.categories.count.should == 1
  end

  scenario "Modifying a transie's categories" do
    @a.deposits.count.should == 0
    rc = prc post "/deposits", { amount: 5, categories: @user.categories.collect { |c| c.id } }
    rc.resp.status.should == 200

    tx = @a.refresh.deposits.first
    tx.categories.count.should > 0

    rc = prc put "/deposits/#{tx.id}", { categories: [ @user.categories.first.id ] }
    rc.resp.status.should == 200

    tx.refresh.categories.count.should == 1
  end

  scenario "Removing all transie categories" do
    @a.deposits.count.should == 0
    rc = prc post "/deposits", { amount: 5, categories: @user.categories.collect { |c| c.id } }
    rc.resp.status.should == 200

    tx = @a.refresh.deposits.first
    tx.categories.count.should > 0

    rc = prc put "/deposits/#{tx.id}", { categories: [] }
    rc.resp.status.should == 200

    tx.refresh.categories.count.should == 0
  end

  scenario "Destroying a transie" do
    @a.deposits.count.should == 0
    rc = prc post "/deposits", { amount: 5 }
    rc.resp.status.should == 200

    tx = @a.refresh.deposits.first

    rc = prc delete "/deposits/#{tx.id}"
    rc.resp.status.should == 200

    @a.refresh.deposits.count.should == 0
  end

end
