describe "Recurring Transactions" do
  TT = Timetastic

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
    rt = mockup_rt({
      amount: 5,
      flow_type: :negative
    })
    @account.recurrings.all.count.should == 1

    @account.balance.to_f.should == 0

    rt.due?(1.day.ahead).should be_true
    rt.commit(1.day.ahead).should be_true
    rt.due?(1.day.ahead).should be_false

    @account = @account.refresh
    @account.balance.to_f.should == -5.0
  end

  it "should commit a daily RT only once a day" do
    rt = mockup_rt({
      amount: 10,
      flow_type: :negative,
      frequency: :daily,
      account: @account
    })

    rt.applicable?(1.day.ahead).should be_true
    rt.commit(1.day.ahead).should be_true
    rt.applicable?(1.day.ahead).should be_false

    @account = @account.refresh
    @account.balance.to_f.should == -10.0

    rt.applicable?(2.days.ahead).should be_true
    rt.applicable?(1.month.ahead).should be_true
    rt.applicable?(1.year.ahead).should be_true
    rt.applicable?(1.day.ago).should be_false
    rt.applicable?(Time.now).should be_false
    rt.applicable?(1.month.ago).should be_false
    rt.applicable?(1.year.ago).should be_false
  end

  it "should commit a monthly RT only once a month" do
    rt = valid! fixture(:recurring, {
      amount: 10,
      flow_type: :negative,
      frequency: :monthly,
      account:    @account,
      recurs_on_day: Time.now.day
    })

    rt.applicable?(1.day.ahead).should be_false
    rt.applicable?(1.month.ahead).should be_true
    rt.applicable?(1.year.ahead).should be_true
    rt.applicable?(1.day.ago).should be_false
    rt.applicable?(1.month.ago).should be_false
    rt.applicable?(1.year.ago).should be_false

    rt.applicable?(1.month.ahead).should be_true
    rt.commit(1.month.ahead).should be_true
    rt.applicable?(1.month.ahead).should be_false

    @account = @account.refresh
    @account.balance.to_f.should == -10.0

    rt = rt.refresh
  end

  it "should commit a yearly RT only once a year" do
    rt = mockup_rt({
      amount: 10,
      flow_type: :negative,
      frequency: :yearly,
      account: @account
    })

    rt.applicable?(1.year.ahead).should be_true
    rt.commit(1.year.ahead).should be_true
    rt.applicable?(1.year.ahead).should be_false

    @account = @account.refresh
    @account.balance.to_f.should == -10.0

    rt.applicable?(1.day.ahead).should    be_false
    rt.applicable?(1.month.ahead).should  be_false
    rt.applicable?(2.years.ahead).should   be_true
    rt.applicable?(1.day.ago).should      be_false
    rt.applicable?(1.month.ago).should    be_false
    rt.applicable?(1.year.ago).should     be_false
  end

  it "should use current year and month in daily RTs" do
    t = valid! fixture(:recurring, {
      frequency: :daily,
      recurs_on_day: 5
    })

    t.recurs_on.year.should   == Time.now.year
    t.recurs_on.month.should  == 1
    t.recurs_on.day.should == 5

    t = valid! fixture(:recurring, {
      frequency: :daily,
      recurs_on_month: 7,
      recurs_on_day: 5
    })
    t.recurs_on.year.should   == Time.now.year
    t.recurs_on.month.should  == 1
    t.recurs_on.day.should == 5
  end

  it "should use current year and zero out month in monthly RTs" do
    t = valid! fixture(:recurring, {
      frequency: :monthly,
      recurs_on_month: 5,
      recurs_on_day: 12
    })

    t.recurs_on.year.should   == Time.now.year
    t.recurs_on.month.should  == 1
    t.recurs_on.day.should == 12

    t = valid! fixture(:recurring, {
      frequency: :monthly,
      recurs_on_month: 7,
      recurs_on_day: 5
    })
    t.recurs_on.year.should   == Time.now.year
    t.recurs_on.month.should  == 1
    t.recurs_on.day.should == 5
  end

  it "should use all of year, month, and day in yearly RTs" do
    t = valid! fixture(:recurring, {
      frequency: :yearly,
      recurs_on_month: 5,
      recurs_on_day: 12
    })

    t.recurs_on.year.should   == Time.now.year
    t.recurs_on.month.should  == 5
    t.recurs_on.day.should == 12

    t = valid! fixture(:recurring, {
      frequency: :yearly,
      recurs_on_month: 7,
      recurs_on_day: 5
    })
    t.recurs_on.year.should   == Time.now.year
    t.recurs_on.month.should  == 7
    t.recurs_on.day.should == 5
  end

  context '#next_billing_date' do
    before(:all) do
      @last_zero_hours_value = Timetastic.zero_hours
      Timetastic.zero_hours = true
    end
    after(:all) do
      Timetastic.zero_hours = @last_zero_hours_value
    end

    it ':yearly' do
      now = Time.now

      t = valid! fixture(:recurring, {
        frequency: :yearly,
        recurs_on_month: 5,
        recurs_on_day: 12,
        created_at: Time.new(2013, 6, 1)
      })

      t.next_billing_date.should == TT.zero(2014, 5, 12)

      t.next_billing_date({
        relative_to: TT.zero(2013, 5, 7)
      }).should == TT.zero(2013, 5, 12)

      t.next_billing_date({
        relative_to: 1.year.ago(t.created_at)
      }).should == TT.zero(2013, 5, 12)

      t.commit(t.next_billing_date).should be_true
      t = t.refresh
      t.next_billing_date.should == TT.zero(2015, 5, 12)

      t.commit(t.next_billing_date).should be_true
      t = t.refresh
      t.next_billing_date.should == TT.zero(2016, 5, 12)
    end

    it ':monthly' do
      t = valid! fixture(:recurring, {
        frequency: :monthly,
        recurs_on_day: 3,
        created_at: Time.new(2013, 6, 1)
      })

      now = TT.zero Time.new(2013,6,2)
      t.next_billing_date(t.commit_anchor, now).should ==
        TT.zero(Time.new(2013, 6, 3))

      now = TT.zero Time.new(2013,6,4)
      t.next_billing_date(t.commit_anchor, now).should ==
        TT.zero(Time.new(2013, 7, 3))

      now = TT.zero Time.new(2013,7,2)
      t.next_billing_date(t.commit_anchor, now).should ==
        TT.zero(Time.new(2013, 7, 3))

      now = TT.zero Time.new(2013,7,3)
      t.next_billing_date(t.commit_anchor, now).should ==
        TT.zero(Time.new(2013, 7, 3))
    end

    it ':daily' do
      now = Time.now

      t = valid! fixture(:recurring, {
        frequency: :daily,
        created_at: Time.new(2013, 6, 1)
      })

      now = TT.zero Time.new(2013,6,1)
      t.next_billing_date(t.commit_anchor, now).should ==
        TT.zero(Time.new(2013, 6, 2))

      now = TT.zero Time.new(2013,6,2)
      t.next_billing_date(t.commit_anchor, now).should ==
        TT.zero(Time.new(2013, 6, 2))

      t.update!({
        created_at: DateTime.now
      })

      t.next_billing_date.should == 1.day.ahead
    end
  end

  context '#all_occurences' do
    before(:all) do
      @last_zero_hours_value = TT.zero_hours
      TT.zero_hours = true
    end
    after(:all) do
      TT.zero_hours = @last_zero_hours_value
    end

    it ':daily' do
      now = Time.now

      t = valid! fixture(:recurring, {
        frequency: :daily,
        created_at: 7.days.ago
      })

      t.all_occurences.length.should == 7

      t.update!({ created_at: 1.month.ago })
      t.all_occurences.length.should == TT.days_between(TT.zero(t.created_at.to_time), TT.zero(Time.now))

      t.update!({ created_at: 1.month.ahead })
      t.all_occurences.length.should == 0

      t.update!({ created_at: 1.week.ago })
      t.all_occurences(3.days.ago).length.should == 4
    end


    # it ':monthly' do
    #   now = TT.zero Time.now

    #   t = valid! fixture(:recurring, {
    #     frequency: :monthly,
    #     created_at: 1.year.ago
    #   })

    #   t.all_occurences.length.should == 12

    #   t.update!({ created_at: 1.month.ago })
    #   t.all_occurences.length.should == 1

    #   t.update!({ created_at: 1.week.ago })
    #   t.all_occurences.length.should == 1

    #   t.update!({ created_at: 1.month.ahead })
    #   t.all_occurences.length.should == 0
    # end


  end



end