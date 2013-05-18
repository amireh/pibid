describe Journal do
  before(:all) do
    module Journal
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
    it '#validate_structure!' do
      j = @u.journals.new({ "scopemap" => 123})
      expect { j.validate_structure! }.to raise_error
      should_reject_with(j, :structure, "must be hash")


      j = @u.journals.new({ "entries" => [] })
      expect { j.validate_structure! }.to raise_error
      should_reject_with(j, :structure, "must be hash")

      j = @u.journals.new({
        "entries" => { "foo" => [] }
      })
      expect { j.validate_structure! }.to raise_error
      should_reject_with(j, :structure, "unrecognized operation")
    end

    it '#validate' do
      j = @u.journals.new({
        "scopemap" => {
          "account_id" => @a.id
        },
        "entries" => {
          "create" => [{
            "id"    => 1234,
            "scope" => "account:transactions",
            "data"  => {}
          }]
        }
      })

      expect { j.validate!(:create, [ 'id', 'scope', 'data' ]) }.not_to raise_error

      # missing id
      j = @u.journals.new({
        "scopemap" => {
          "account_id" => @a.id
        },
        "entries" => {
          "create" => [{
            "scope" => "account:transactions",
            "data"  => {}
          }]
        }
      })

      expect { j.validate!(:create, [ 'id', 'scope', 'data' ]) }.to raise_error
      should_reject_with(j, :entries, "missing id")

      # missing scope
      j = @u.journals.new({
        "scopemap" => {
          "account_id" => @a.id
        },
        "entries" => {
          "create" => [{
            "id"    => 1234,
            "data"  => {}
          }]
        }
      })

      expect { j.validate!(:create, [ 'id', 'scope', 'data' ]) }.to raise_error
      should_reject_with(j, :entries, "missing scope")

      # missing data
      j = @u.journals.new({
        "scopemap" => {
          "account_id" => @a.id
        },
        "entries" => {
          "create" => [{
            "id"    => 1234,
            "scope" => "account:transactions"
          }]
        }
      })

      expect { j.validate!(:create, [ 'id', 'scope', 'data' ]) }.to raise_error
      should_reject_with(j, :entries, "missing data")
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

    context "Committing" do

      it 'processing a DELETE entry' do
        @t = valid! fixture(:deposit)

        j = @u.journals.new({
          "scopemap" => {
            "account_id" => @a.id
          },
          "entries" => {
            "delete" => [{
              "id" => @t.id,
              "scope" => "account:transactions"
            }]
          }
        })

        expect { j.commit }.not_to raise_error
        j.processed[:total].should == 1
      end


      it 'processing a CREATE entry' do
        j = @u.journals.new({
          "scopemap" => {
            "account_id" => @a.id
          },
          "entries" => {
            "create" => [{
              "id"    => "c123",
              "scope" => "account:transactions",
              "data"  => {
                "amount"  => 5.95,
                "type"    => "deposit"
              }
            }]
          }
        })

        j.operator = app_instance

        expect { j.commit }.not_to raise_error
        j.processed[:total].should == 1
        @u.account.deposits.length.should == 1
        @u.account.deposits.first.id.should == j.shadowmap['c123']
      end


    end

  end
end