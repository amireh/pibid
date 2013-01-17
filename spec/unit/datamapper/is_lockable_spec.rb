# --------- -------
# DISABLED: LOCKING
# --
if false
  describe User do
    before do
      unless User.destroy
        # User.each { |u| u.accounts.first.unlock!; u.unlock! }
        User.each { |u|  u.unlock! }
        User.destroy
      end

      mockup_user
    end

    it "should prohibit updating a locked user" do
      @user.update({ name: "meme" })
      @user.refresh.name.should == "meme"

      @user.lock!

      @user.update({ name: "dongle" }).should be_false
      expect { @user.update!({ name: "dongle" }) }.to raise_error(DataMapper::UpdateConflictError)
      @user.name = "dongle"
      @user.save.should be_false
      @user.destroy.should be_false
      @user.refresh.name.should == "meme"
    end

    after do
      @user.unlock!
    end

    it "should unlock a user" do
      @user.update({ name: "meme" })
      @user.refresh.name.should == "meme"

      @user.lock!

      @user.refresh.update({ name: "dongle" }).should be_false
      @user.refresh.name.should == "meme"

      @user.unlock!

      @user.refresh.update({ name: "dongle" }).should be_true
      @user.refresh.name.should == "dongle"
    end

    it "should lock and unlock and re-lock a user" do
      @user.update({ name: "meme" })
      @user.refresh.name.should == "meme"

      @user.lock!

      @user.update({ name: "dongle" }).should be_false
      @user.refresh.name.should == "meme"

      @user.unlock!

      @user.refresh.update({ name: "dongle" }).should be_true
      @user.refresh.name.should == "dongle"

      @user.lock!

      @user.refresh.update({ name: "meme" }).should be_false
      @user.refresh.name.should == "dongle"
    end

    it "should not allow a transaction to be created while locked" do
      @user.lock!
      @account.withdrawals.create({ amount: 5 }).saved?.should be_false
    end

  end
end