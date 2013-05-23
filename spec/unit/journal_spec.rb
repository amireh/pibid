describe Journal do
  before(:all) do
    class Journal
      public :validate!, :validate_structure!, :resolve_scope!, :resolve_collection!
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
      it " scopemap" do
        j = @u.journals.new({
          scopemap: 123
        })
        expect { j.validate_structure! }.to raise_error
        should_reject_with(j, :structure, "scope map must be hash")
      end

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
            bar: {}
          }
        })

        expect { j.validate_structure! }.to raise_error
        should_reject_with(j, :structure, "missing scope identifier")
      end

      it "scope collections" do
        j = @u.journals.new({
          scopemap: { bar_id: 1 },
          entries: {
            bar: []
          }
        })

        expect { j.validate_structure! }.to raise_error
        should_reject_with(j, :structure, "collections must be hash")
      end

      it "collection operations" do
        j = @u.journals.new({
          scopemap: { account_id: 1 },
          entries: {
            account: {
              transactions: []
            }
          }
        })

        expect { j.validate_structure! }.to raise_error
        should_reject_with(j, :structure, "collection operations must be hash")
      end

      it "scope collection operation listing" do
        j = @u.journals.new({
          scopemap: { account_id: 1 },
          entries: {
            account: {
              transactions: {
                create: {}
              }
            }
          }
        })

        expect { j.validate_structure! }.to raise_error
        should_reject_with(j, :structure, "operation entries must be array")
      end

      it "an invalid operation" do
        j = @u.journals.new({
          scopemap: {
            account_id: 1
          },
          entries: {
            account: {
              transactions: {
                foo: []
              }
            }
          }
        })

        expect { j.validate_structure! }.to raise_error
        should_reject_with(j, :structure, "unrecognized operation")
      end

    end

    context "Operation validation" do
      it "a valid operation" do
        j = @u.journals.new({
          scopemap: {
            account_id: @a.id
          },
          entries: {
            account: {
              transactions: {
                create: [{
                  id: 'c123',
                  data: {}
                }]
              }
            }
          }
        })

        expect { j.validate!(:create, j.entries["account"]["transactions"]) }.not_to raise_error
      end

      it "missing a key" do
        j = @u.journals.new({
          scopemap: {
            account_id: @a.id
          },
          entries: {
            account: {
              transactions: {
                create: [{
                  data: {}
                }]
              }
            }
          }
        })

        expect { j.validate!(:create, j.entries["account"]["transactions"]) }.to raise_error
        should_reject_with(j, :entries, "missing id")
      end

      it "invalid data" do
        j = @u.journals.new({
          scopemap: {
            account_id: @a.id
          },
          entries: {
            account: {
              transactions: {
                create: [{
                  id: 'c123',
                  data: []
                }]
              }
            }
          }
        })

        expect { j.validate!(:create, j.entries["account"]["transactions"]) }.to raise_error
        should_reject_with(j, :entries, "expected data to be hash")
      end

    end

    context "Scope resolution" do
      it '#resolve_scope!(user:account)' do
        j = @u.journals.new({
          "scopemap" => {
            "account_id" => @account.id
          }
        })

        j.resolve_scope!("account", @u).should == @u.account
      end

      it '#resolve_scope!(user:categories)' do
        @c = @u.categories.first

        j = @u.journals.new({
          "scopemap" => {
            "category_id" => @c.id
          }
        })

        j.resolve_scope!("category", @u).should == @c
      end

      it '#resolve_scope!(user:payment_methods)' do
        @pm = @u.payment_methods.first

        j = @u.journals.new({
          "scopemap" => {
            "payment_method_id" => @pm.id
          }
        })

        j.resolve_scope!("payment_method", @u).should == @pm
      end

      it '#resolve_scope!(account:transactions)' do
        @d = valid! fixture(:deposit)

        j = @u.journals.new({
          "scopemap" => {
            "transaction_id" => @d.id
          }
        })

        j.resolve_scope!("transaction", @account).should == @d
      end

      it '#resolve_scope!(invalid scope)' do
        j = @u.journals.new({
          "scopemap" => {
            "bar_id" => 0
          },
          "entries" => {
            "create" => [{
              "scope" => "bar"
            }]
          }
        })

        expect { j.resolve_scope!("bar", @user) }.to raise_error
        j.errors[:scopes].length.should == 1
        j.errors[:scopes].first.should match('Unrecognized scope')
      end

      it '#resolve_scope!(missing scope id)' do
        j = @u.journals.new({
          "scopemap" => {
          },
          "entries" => {
            "create" => [{
              "scope" => "account:transactions"
            }]
          }
        })

        expect { j.resolve_scope!("account", @user) }.to raise_error
        j.errors[:scopes].length.should == 1
        j.errors[:scopes].first.should match('Missing scope identifier')
      end

      it '#resolve_scope!(bad scope id)' do
        j = @u.journals.new({
          "scopemap" => {
            "account_id" => 98127392187389
          },
          "entries" => {
            "create" => [{
              "scope" => "account:transactions"
            }]
          }
        })

        expect { j.resolve_scope!("account", @user) }.to raise_error
        j.errors[:scopes].length.should == 1
        j.errors[:scopes].first.should match('No such account')
      end

    end

    context "Scope collection resolution" do
      it '#resolve_collection!(account:transactions)' do
        j = @u.journals.new({
          "scopemap" => {
            "account_id" => @a.id
          },
          "entries" => {
            "create" => [{
              "scope" => "account:transactions"
            }]
          }
        })

        j.resolve_scope!("account", @user).should == @account
        j.resolve_collection!("transactions", @account).should == @a.transactions
      end

      it '#resolve_collection!(bad collection)' do
        j = @u.journals.new({
          "scopemap" => {
            "account_id" => @a.id
          },
          "entries" => {
            "create" => [{
              "scope" => "account:bar"
            }]
          }
        })

        j.resolve_scope!("account", @user).should == @account
        expect { j.resolve_collection!("bar", @account) }.to raise_error
        j.errors[:collections].length.should == 1
        j.errors[:collections].first.should match('Unrecognized collection')
      end


    end # Scope collection resolution

  end
end