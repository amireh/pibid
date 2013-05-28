describe "Recurring Transactions" do

  before(:all) do
    valid! fixture(:user)
  end

  before(:each) do
    @a = @account = @account.refresh
    @a.recurrings.destroy
    @a.transactions.destroy
  end

  def mockup_rt(q = {})
    valid! fixture(:recurring, q)
  end

  it "should create a recurring transaction" do
    valid! fixture(:recurring)
  end

  context "validation" do
    it "should validate recurrence in yearly frequency" do
      invalid!  fixture(:recurring, { frequency: :yearly, recurs_on_month: nil })
      invalid!  fixture(:recurring, { frequency: :yearly, recurs_on_month: 1, recurs_on_day: nil })
      invalid!  fixture(:recurring, { frequency: :yearly, recurs_on_month: -1, recurs_on_day: 1 })
      invalid!  fixture(:recurring, { frequency: :yearly, recurs_on_month: 1, recurs_on_day: 300 })
      invalid!  fixture(:recurring, { frequency: :yearly, recurs_on_month: 1, recurs_on_day: 35 })

      valid!    fixture(:recurring, { frequency: :yearly, recurs_on_month: 1, recurs_on_day: 1 })
      valid!    fixture(:recurring, { frequency: :yearly, recurs_on_month: 8, recurs_on_day: 19 })
    end

    it "should validate recurrence in monthly frequency" do
      invalid!  fixture(:recurring, { frequency: :monthly, recurs_on_day: nil })
      invalid!  fixture(:recurring, { frequency: :monthly, recurs_on_day: 300 })
      invalid!  fixture(:recurring, { frequency: :monthly, recurs_on_day: 'me' })
      invalid!  fixture(:recurring, { frequency: :monthly, recurs_on_day: -5 })

      valid!    fixture(:recurring, { frequency: :monthly, recurs_on_day: 15 })
      valid!    fixture(:recurring, { frequency: :monthly, recurs_on_day: 1 })
      valid!    fixture(:recurring, { frequency: :monthly, recurs_on_day: 28 })
    end

    it "should validate flow type" do
      invalid!  fixture(:recurring, { frequency: :daily, flow_type: :bar })
      invalid!  fixture(:recurring, { frequency: :daily, flow_type: 5 })

      valid!    fixture(:recurring, { frequency: :daily, flow_type: :negative })
      valid!    fixture(:recurring, { frequency: :daily, flow_type: :positive })
    end

    it "should require a note" do
      invalid! fixture(:recurring, { note: nil })
      invalid! fixture(:recurring, { note: '' })
    end
  end


  it "should commit a recurring transaction" do
    @account.recurrings.all.count.should == 0
    rt = mockup_rt({ amount: 5 })
    @account.recurrings.all.count.should == 1

    @account.balance.to_f.should == 0

    rt.commit.should be_true

    @account = @account.refresh
    @account.balance.to_f.should == 5.0
  end

  it "should tag a generated transaction" do
    @account.recurrings.all.count.should == 0

    rt = mockup_rt({
      amount: 5,
      frequency: :daily,
      categories: @user.categories[0..1].map(&:id)
    })

    @account.recurrings.all.count.should == 1

    t = rt.commit
    t.should be_true
    t.categories.length.should == 2

    @account = @account.refresh
    @account.balance.to_f.should == 5.0
  end

  it "should respect the type of a recurring transaction" do
    @account.recurrings.all.count.should == 0
    rt = mockup_rt({ amount: 5, flow_type: :negative })
    @account.recurrings.all.count.should == 1

    @account.balance.to_f.should == 0

    rt.commit.should be_true

    @account = @account.refresh
    @account.balance.to_f.should == -5.0
  end

  it "should not commit the transaction more than necessary" do
    @account.recurrings.all.count.should == 0
    rt = mockup_rt({ amount: 5, flow_type: :negative })
    @account.recurrings.all.count.should == 1

    @account.balance.to_f.should == 0

    rt.applicable?.should be_true
    rt.commit.should be_true
    rt.applicable?.should be_false

    @account = @account.refresh
    @account.balance.to_f.should == -5.0

    rt.commit.should be_false
  end

  it "should commit a daily RT only once a day" do
    rt = mockup_rt({
      amount: 10,
      flow_type: :negative,
      frequency: :daily,
      account: @account
    })

    rt.applicable?.should be_true
    rt.commit.should be_true
    rt.applicable?.should be_false

    @account = @account.refresh
    @account.balance.to_f.should == -10.0

    t = Time.now

    rt.applicable?(1.day.ahead).should be_true
    rt.applicable?(1.month.ahead).should be_true
    rt.applicable?(1.year.ahead).should be_true
    rt.applicable?(1.day.ago).should be_false
    rt.applicable?(1.month.ago).should be_false
    rt.applicable?(1.year.ago).should be_false
  end

  it "should commit a monthly RT only once a month" do
    rt = mockup_rt({
      amount: 10,
      flow_type: :negative,
      frequency: :monthly,
      account:    @account
    })

    rt.applicable?.should be_true
    rt.commit.should be_true
    rt.applicable?.should be_false

    @account = @account.refresh
    @account.balance.to_f.should == -10.0

    rt = rt.refresh

    rt.applicable?(1.day.ahead).should be_false
    rt.applicable?(DateTime.new(1.month.ahead.year, 1.month.ahead.month, rt.recurs_on.day)).should be_true
    rt.applicable?(1.year.ahead).should be_true
    rt.applicable?(1.day.ago).should be_false
    rt.applicable?(1.month.ago).should be_false
    rt.applicable?(1.year.ago).should be_false
  end

  it "should commit a yearly RT only once a year" do
    rt = mockup_rt({
      amount: 10,
      flow_type: :negative,
      frequency: :yearly,
      account: @account
    })

    rt.applicable?.should be_true
    rt.commit.should be_true
    rt.applicable?.should be_false

    @account = @account.refresh
    @account.balance.to_f.should == -10.0

    rt.applicable?(1.day.ahead).should    be_false
    rt.applicable?(1.month.ahead).should  be_false
    rt.applicable?(1.year.ahead).should   be_true
    rt.applicable?(1.day.ago).should      be_false
    rt.applicable?(1.month.ago).should    be_false
    rt.applicable?(1.year.ago).should     be_false
  end

end