if false # disabled for now

  class LocatorDelegate; include Sinatra::Locator::Helpers; end

  describe DataMapper::Is::Locatable do

    before do mockup_user; @d = LocatorDelegate.new end

    it "should generate user resource paths" do
      @d.url_for(@user).should == "/users/#{@user.id}"
      @d.url_for(@user, :edit).should == "/users/#{@user.id}/edit"
      @d.url_for(@user, :settings, :preferences).should == "/users/#{@user.id}/settings/preferences"
    end

    it "should generate user collection paths" do
      @d.url_for(User).should          == '/users'
      @d.url_for(User, :index).should  == '/users'
      @d.url_for(User, :new).should    == '/users/new'
    end

    it "should generate category paths" do
      @c = @user.categories.create({ name: 'Food' })

      @d.url_for(@c).should == "/users/#{@user.id}/categories/#{@c.id}"
      @d.url_for(@c, :edit).should == "/users/#{@user.id}/categories/#{@c.id}/edit"
      @d.url_for(@c, :destroy).should == "/users/#{@user.id}/categories/#{@c.id}/destroy"
    end

    it "should generate category collection paths" do
      @d.url_for(@user.categories).should == "/users/#{@user.id}/categories"
      @d.url_for(@user.categories, :index).should == "/users/#{@user.id}/categories"
      @d.url_for(@user.categories, :new).should == "/users/#{@user.id}/categories/new"
    end

    it "should generate notice paths" do
      n = @user.notices.first

      @d.url_for(n).should match("/users/#{@user.id}/notices/#{n.salt}")
      @d.url_for(n, :accept).should == "/users/#{@user.id}/notices/#{n.salt}/accept"
    end

    it "should generate notice collection paths" do
      n = @user.notices.first

      @d.url_for(@user.notices, :index).should match("/users/#{@user.id}/notices")
      @d.url_for(@user.notices, :new).should == "/users/#{@user.id}/notices/new"
    end

    it "should generate account paths" do
      @d.url_for(@account).should == "/users/#{@user.id}/accounts/#{@account.id}"
      @d.url_for(@user.accounts.first).should == "/users/#{@user.id}/accounts/#{@account.id}"
    end

    it "should generate account transaction paths" do
      tx = @a.deposits.create({ amount: 5 })
      @d.url_for(tx).should == "/accounts/#{@account.id}/deposits/#{tx.id}"

      tx = @a.withdrawals.create({ amount: 5 })
      @d.url_for(tx).should == "/accounts/#{@account.id}/withdrawals/#{tx.id}"

      tx = @a.recurrings.create({ amount: 5 })
      @d.url_for(tx).should == "/accounts/#{@account.id}/recurrings/#{tx.id}"
    end

    it "should generate account transaction collection paths" do
      5.times do
        @account.deposits.create({ amount: 5 })
        @account.withdrawals.create({ amount: 5 })
      end

      @account = @account.refresh

      @account.deposits.count.should == 5
      @account.withdrawals.count.should == 5

      @d.url_for(@account.deposits, :new).should == "/accounts/#{@account.id}/deposits/new"
      @d.url_for(@account.withdrawals, :new).should == "/accounts/#{@account.id}/withdrawals/new"
      puts @d.url_for(@account.deposits, :new)
      puts @d.url_for(@account.withdrawals, :new)
    end

    it "should obey the shallow option" do
      tx = @a.deposits.create({ amount: 5 })
      @d.url_for(tx, shallow: true).should == "/deposits/#{tx.id}"

      @d.url_for(@user.categories, :edit, shallow: true).should == '/categories/edit'
    end

  end

end