describe Journal do
  before(:all) do
    class Journal
      attr_accessor :ctx
      public :validate!,
        :validate_structure!,
        :resolve_scope!,
        :resolve_collection!,
        :current_scope_id,
        :current_collection_id,
        :current_collection_fqid,
        :resolve_dependencies

    end

    @u = valid! fixture(:user)
    @a = @u.account
  end

  def should_reject_with(j, property, keywords)
    j.errors[property].length.should == 1
    j.errors[property].first.downcase.should match(keywords.split(' ').join('.*'))
  end

  context "Instance methods" do
    context "Structure validation" do
      # it " scopemap" do
      #   j = @u.journals.new({
      #     scopemap: 123
      #   })
      #   expect { j.validate_structure! }.to raise_error
      #   should_reject_with(j, :structure, "scope map must be hash")
      # end

      it "scope listing" do
        j = @u.journals.new({
          entries: []
        })

        expect { j.validate_structure! }.to raise_error
        should_reject_with(j, :structure, "scope listing must be hash")
      end

      it "an unmapped scope" do
        j = @u.journals.new({
          entries: {
            bar: [{}]
          }
        })

        expect { j.validate_structure! }.to raise_error
        should_reject_with(j, :structure, "missing scope identifier")
      end

      # it "collection operations" do
      #   j = @u.journals.new({
      #     entries: {
      #       accounts: [{
      #         id: 1,
      #         transactions: []
      #       }]
      #     }
      #   })

      #   expect { j.validate_structure! }.to raise_error
      #   should_reject_with(j, :structure, "collection operations must be hash")
      # end

      it "scope collection operation listing" do
        j = @u.journals.new({
          entries: {
            accounts: [{
              id: 1,
              transactions: {
                create: {}
              }
            }]
          }
        })

        expect { j.validate_structure! }.to raise_error
        should_reject_with(j, :structure, "operation entries must be array")
      end

      it "an invalid operation" do
        j = @u.journals.new({
          entries: {
            accounts: [{
              id: 1,
              transactions: {
                foo: []
              }
            }]
          }
        })

        expect { j.validate_structure! }.to raise_error
        should_reject_with(j, :structure, "unrecognized operation")
      end

    end

    context "Operation validation" do
      it "a valid operation" do
        j = @u.journals.new()

        expect {
          j.validate!(:create, {
            create: [{
              id: 'c123',
              data: {}
            }]
          })
        }.not_to raise_error
      end

      it "missing a key" do
        j = @u.journals.new

        expect {
          j.validate!(:create, {
            create: [{
              data: {}
            }]
          })
        }.to raise_error
        should_reject_with(j, :entries, "missing id")
      end

      it "invalid data" do
        j = @u.journals.new

        expect {
          j.validate!(:create, {
            create: [{
              id: 'c123',
              data: []
            }]
          })
        }.to raise_error

        puts j.errors.inspect
        should_reject_with(j, :entries, "expected data to be hash")
      end

    end

    context "Scope resolution" do
      it '#resolve_scope!(user:account)' do
        @user.journals.new.resolve_scope!("account", @account.id, @user).should == @account
      end

      it '#resolve_scope!(invalid scope)' do
        j = @u.journals.new()

        expect { j.resolve_scope!("bar", 1, @user) }.to raise_error
        j.errors[:scopes].length.should == 1
        j.errors[:scopes].first.should match('Unrecognized scope')
      end

      it '#resolve_scope!(bad scope id)' do
        j = @u.journals.new()

        expect { j.resolve_scope!("account", 12345678, @user) }.to raise_error
        j.errors[:scopes].length.should == 1
        j.errors[:scopes].first.should match('No such account')
      end

    end

    context "Scope collection resolution" do
      it '#resolve_collection!(account:transactions)' do
        j = @u.journals.new()

        j.resolve_scope!("account", @account.id, @user).should == @account
        j.resolve_collection!("transactions", @account).should == @a.transactions
      end

      it '#resolve_collection!(bad collection)' do
        j = @u.journals.new()

        j.resolve_scope!("account", @a.id, @user).should == @account

        expect {
          j.resolve_collection!("bar", @account)
        }.to raise_error

        j.errors[:collections].length.should == 1
        j.errors[:collections].first.should match('Unrecognized collection')
      end


    end # Scope collection resolution

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

  context "Dependency resolution" do
    it "#resolve_dependencies" do
      j = @u.journals.new({
        entries: {
          accounts:  [{}],
          users:     [{}]
        }
      })

      j.resolve_dependencies
      j.entries.to_a[0][0].should == "users"

      j = @u.journals.new({
        entries: {
          users: [{
            accounts: [{
              transactions: {}
            }],
            payment_methods: {},
            categories: {}
          }]
        }
      })

      j.resolve_dependencies
      puts j.entries
      j.entries["users"][0].to_a.flatten.index("categories").should == 0
      j.entries["users"][0].to_a.flatten.index("payment_methods").should == 2
      j.entries["users"][0].to_a.flatten.index("accounts").should == 4
    end
  end
end