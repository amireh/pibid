describe Account do
  before(:each) do
    @a = valid! fixture(:account, { currency: "USD" })
  end

  def some_currency
    currencies    = Currency.all
    currencies[rand(currencies.length)]
  end

  it "should update its balance when currency changes" do
    @a.update!({ balance: 10.0 })
    @c = some_currency
    @a.update({ currency: @c.name })
    @a.refresh.balance.to_f.should == @c.from("USD", 10.0)
  end
end