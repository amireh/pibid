describe Journal do
  before(:all) do
    class Journal
      attr_accessor :ctx
      public :current_scope_id, :current_collection_id, :current_collection_fqid
    end

    @u = valid! fixture(:user)
    @a = @u.account
  end

  context "Instance methods" do

    it '#current_scope_id' do
      j = @user.journals.new
      j.ctx = Journal::Context.new
      j.ctx.scope = User.new
      j.current_scope_id.should == 'user'
    end

    it '#current_collection_id' do
      j = @user.journals.new
      j.ctx = Journal::Context.new
      j.ctx.scope = User.new
      j.ctx.collection = j.ctx.scope.categories
      j.current_collection_id.should == 'categories'

      j.ctx.collection = j.ctx.scope.payment_methods
      j.current_collection_id.should == 'payment_methods'
    end

    it '#current_collection_fqid' do
      j = @user.journals.new
      j.ctx = Journal::Context.new
      j.ctx.scope = User.new
      j.ctx.collection = j.ctx.scope.categories
      j.current_collection_fqid.should == 'user_categories'

      j.ctx.collection = j.ctx.scope.payment_methods
      j.current_collection_fqid.should == 'user_payment_methods'
    end
  end
end