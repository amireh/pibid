describe "Recurring Transactions" do
  def zero(*args)
    Recurring.new.zero(*args)
  end

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
      invalid!  fixture(:recurring, { frequency: :yearly, yearly_months: [nil] })
      invalid!  fixture(:recurring, { frequency: :yearly, yearly_months: [1],  yearly_day: nil })
      invalid!  fixture(:recurring, { frequency: :yearly, yearly_months: [-1], yearly_day: 1 })
      invalid!  fixture(:recurring, { frequency: :yearly, yearly_months: [1],  yearly_day: 300 })
      invalid!  fixture(:recurring, { frequency: :yearly, yearly_months: [1],  yearly_day: 35 })

      valid!    fixture(:recurring, { frequency: :yearly, yearly_months: [1], yearly_day: 1 })
      valid!    fixture(:recurring, { frequency: :yearly, yearly_months: [8,2], yearly_day: 19 })
    end

    it "should validate recurrence in monthly frequency" do
      invalid!  fixture(:recurring, { frequency: :monthly, monthly_days: nil })
      invalid!  fixture(:recurring, { frequency: :monthly, monthly_days: [300] })
      invalid!  fixture(:recurring, { frequency: :monthly, monthly_days: 'me' })
      invalid!  fixture(:recurring, { frequency: :monthly, monthly_days: -5 })

      valid!    fixture(:recurring, { frequency: :monthly, monthly_days: [15] })
      valid!    fixture(:recurring, { frequency: :monthly, monthly_days: [1,6 ]})
      valid!    fixture(:recurring, { frequency: :monthly, monthly_days: [28] })
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
    rt = mockup_rt({ amount: 5, created_at: Date.today-1 })

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
      created_at: Date.today-1,
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
    rt = mockup_rt({
      amount: 5,
      flow_type: :negative,
      created_at: Date.today-1
    })
    @account.recurrings.all.count.should == 1

    @account.balance.to_f.should == 0

    rt.commit.should be_true

    @account = @account.refresh
    @account.balance.to_f.should == -5.0
  end

  describe 'committing' do

    it "should commit a daily RT only once a day" do
      rt = mockup_rt({
        amount: 10,
        flow_type: :negative,
        frequency: :daily,
        account: @account,
        created_at: Date.today - 1
      })

      rt.due?.should be_true
      rt.commit.should be_true
      rt.due?.should be_false

      @account = @account.refresh
      @account.balance.to_f.should == -10.0
    end

    it "should commit a monthly RT only once a month" do
      rt = valid! fixture(:recurring, {
        amount: 10,
        flow_type: :negative,
        frequency: :monthly,
        account:    @account,
        created_at: Date.today - 1,
        monthly_days: [ Time.now.day ]
      })

      rt.due?.should be_true
      rt.commit.should be_true
      rt.due?.should be_false

      @account.refresh.balance.to_f.should == -10.0
    end

    it "should commit a yearly RT only once a year" do
      rt = mockup_rt({
        amount: 10,
        flow_type: :negative,
        frequency: :yearly,
        created_at: Date.today - 1,
        account: @account,
        yearly_day: Date.today.day,
        yearly_months: [ Date.today.month ]
      })

      rt.due?.should be_true
      rt.commit.should be_true
      rt.due?.should be_false

      rt.account.balance.to_f.should == -10.0
    end

    it "committing all outstanding occurrences" do
      rt = mockup_rt({
        amount: 10,
        flow_type: :negative,
        frequency: :daily,
        created_at: Date.today - 7,
        account: @account
      })

      rt.account.withdrawals.count.should == 0
      rt.all_occurrences.count.should == 7

      while rt.due?
        rt.commit
      end

      rt.account.withdrawals.count.should == 7
      rt.account.balance.to_f.should == -70.0
    end
  end

  describe 'parsing recurrence rules' do
    it "should ignore day, month, and year fields in daily RTs" do
      t = valid! fixture(:recurring, {
        frequency: :daily,
        recurs_on_day: 5
      })

      t.recurs_on.year.should   == Time.now.year
      t.recurs_on.month.should  == 1
      t.recurs_on.day.should    == 1

      t = valid! fixture(:recurring, {
        frequency: :daily,
        recurs_on_month: 7,
        recurs_on_day: 12
      })

      t.recurs_on.year.should   == Time.now.year
      t.recurs_on.month.should  == 1
      t.recurs_on.day.should == 1
    end

    it "should ignore month and year fields in monthly RTs" do
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

    it "should ignore the year field in yearly RTs" do
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
  end

  context '#next_billing_date' do
    describe ':yearly' do
      t = nil

      before :each do
        t = valid! fixture(:recurring, {
          frequency: :yearly,
          yearly_months: [5],
          yearly_day: 12
        })
      end

      scenario 'a month past' do
        t.update!({ created_at: Time.utc(2013, 6, 12) })
        t.next_billing_date.should == zero(2014, 5, 12)
      end

      scenario 'several months before' do
        t.update!({ created_at: Time.utc(2013, 2, 12) })
        t.next_billing_date.should == zero(2013, 5, 12)
      end

      scenario 'same year, same month, same day' do
        t.update!({ created_at: Time.utc(2013, 5, 12) })
        t.next_billing_date.should == zero(2014, 5, 12)
      end

      scenario 'same month, several days before' do
        t.update!({ created_at: Time.utc(2013, 5, 7) })
        t.next_billing_date.should == zero(2013, 5, 12)
      end

      scenario 'same month, one day past' do
        t.update!({ created_at: Time.utc(2012, 5, 13) })
        t.next_billing_date.should == zero(2013, 5, 12)
      end

      scenario 'same month, same day, different year' do
        t.update!({ created_at: Time.utc(2012, 5, 12) })
        t.next_billing_date.should == zero(2013, 5, 12)
      end
    end

    describe ':monthly' do
      t = nil

      before :each do
        t = valid! fixture(:recurring, {
          frequency: :monthly,
          monthly_days: [3]
        })
      end

      scenario 'same month, a few days before' do
        t.update!({ created_at: Time.utc(2013, 6, 1) })
        t.next_billing_date.should == Time.utc(2013, 6, 3)
      end

      scenario 'same month, same day' do
        t.update!({ created_at: Time.utc(2013, 6, 3) })
        t.next_billing_date.should == Time.utc(2013, 7, 3)
      end

      scenario 'same month, a few days past' do
        t.update!({ created_at: Time.utc(2013, 6, 4) })
        t.next_billing_date.should == Time.utc(2013, 7, 3)
      end

      scenario 'last month of year' do
        t.update!({ created_at: Time.utc(2013, 12, 4) })
        t.next_billing_date.should == Time.utc(2014, 1, 3)
      end
    end

    describe ':daily' do
      t = nil

      before :each do
        t = valid! fixture(:recurring, {
          frequency: :daily
        })
      end

      scenario 'start of month' do
        t.update!({ created_at: Time.utc(2013, 6, 1) })
        t.next_billing_date.should == Time.utc(2013, 6, 2)
      end

      scenario 'end of month' do
        t.update!({ created_at: Time.utc(2013, 6, 30) })
        t.next_billing_date.should == Time.utc(2013, 7, 1)
      end

      # June has 30 days, should wrap
      scenario 'wraps at end of month' do
        t.update!({ created_at: Time.utc(2013, 6, 31) })
        t.next_billing_date.should == Time.utc(2013, 7, 2)
      end

      scenario 'start of year' do
        t.update!({ created_at: Time.utc(2013, 1, 1) })
        t.next_billing_date.should == Time.utc(2013, 1, 2)
      end

      scenario 'end of year' do
        t.update!({ created_at: Time.utc(2013, 12, 31) })
        t.next_billing_date.should == Time.utc(2014, 1, 1)
      end
    end
  end

  describe '#due?' do
  end

  context '#all_occurrences' do
    it ':daily' do
      now = Time.now

      t = valid! fixture(:recurring, {
        frequency: :daily,
        created_at: 7.days.ago
      })

      t.all_occurrences.length.should == 7

      t.update!({ created_at: 1.month.ago })
      t.all_occurrences.length.should == Time.days_in_month(1.month.ago.month, 1.month.ago.year)

      t.update!({ created_at: 1.month.from_now })
      t.all_occurrences.length.should == 0

      t.update!({ created_at: 1.week.ago })
      t.all_occurrences(3.days.ago).length.should == 4
    end


    it ':monthly' do
      t = valid! fixture(:recurring, {
        frequency: :monthly,
        monthly_days: [ Time.now.day ],
        created_at: 1.year.ago
      })

      t.all_occurrences.length.should == 12

      t.update!({ created_at: 1.month.ago })
      t.all_occurrences.length.should == 1

      t.update!({ created_at: 1.week.ago })
      t.all_occurrences.length.should == 1

      t.update!({ created_at: 1.month.from_now })
      t.all_occurrences.length.should == 0
    end


    it ':yearly' do
      t = valid! fixture(:recurring, {
        frequency: :yearly,
        yearly_day: Time.now.day,
        yearly_months: [ Time.now.month ],
        created_at: 10.year.ago
      })

      t.all_occurrences.length.should == 10

      t.update!({ created_at: 1.month.ago })
      t.all_occurrences.length.should == 1

      t.update!({ created_at: 1.week.ago })
      t.all_occurrences.length.should == 1

      t.update!({ created_at: 1.month.from_now })
      t.all_occurrences.length.should == 0
    end
  end


  context 'multiple occurrences' do
    it ':monthly' do
      t = valid! fixture(:recurring, {
        frequency: :monthly,
        monthly_days: [ Time.now.day ],
        created_at: 1.year.ago
      })

      t.all_occurrences.length.should == 12

      t.update!({ created_at: 1.month.ago })
      t.all_occurrences.length.should == 1

      t.update!({ created_at: 1.week.ago })
      t.all_occurrences.length.should == 1

      t.update!({ created_at: 1.month.from_now })
      t.all_occurrences.length.should == 0
    end

    it ':yearly' do
      t = valid! fixture(:recurring, {
        frequency: :yearly,
        yearly_day: Time.now.day,
        yearly_months: [ 3, 9 ],
        created_at: 1.year.ago
      })

      t.all_occurrences.length.should == 2

      t.update!({ created_at: 0.years.ago.beginning_of_year + 4.months })
      t.all_occurrences.length.should == 1
    end
  end
end