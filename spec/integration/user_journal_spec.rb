feature "Journaling" do
  before(:all) do
    valid! fixture :user
  end

  before :each do
    sign_in @user
  end

  context "Validating a Journal" do

    context "Scopes & Collections" do

      it "should locate a scope" do
        data = {
          scopes: {
            account_id: @account.id
          },

          create: [
            {
              id:     1234,
              scope: "account:transactions",
              data: {
              }
            }
          ]
        }

        rc = api_call post "/users/#{@user.id}/journal", data
        rc.should succeed
      end

      it "should reject an invalid scope" do
        data = {
          accountsz_id: 1,
          create: [
            {
              id: 1234,
              shadow: true,
              scope: "accountsz:transactions",
              data: {
              }
            }
          ]
        }

        rc = api_call post "/users/#{@user.id}/journal", data
        rc.should fail(400, 'Invalid scope')
      end

      it "should require a scope identifier" do
        data = {
          create: [
            {
              id: 1234,
              shadow: true,
              scope: "account:transactions",
              data: {
              }
            }
          ]
        }

        rc = api_call post "/users/#{@user.id}/journal", data
        rc.should fail(400, 'Missing scope identifier')
      end


      it "should require reject an invalid collection" do
        data = {
          account_id: @account.id,
          create: [
            {
              id: 1234,
              shadow: true,
              scope: "account:transactionsxz",
              data: {
              }
            }
          ]
        }

        rc = api_call post "/users/#{@user.id}/journal", data
        rc.should fail(400, 'Invalid collection')
      end
    end

    context "Entries" do
      it "should reject CREATE with no id" do
        rc = api_call post "/users/#{@user.id}/journal", {
          account_id: @account.id,
          create: [{
            data: {
            }
          }]
        }
        rc.should fail(400, 'Missing entry data id')
      end

      it "should reject CREATE with no scope" do
        rc = api_call post "/users/#{@user.id}/journal", {
          account_id: @account.id,
          create: [{
            id: 1234,
            data: {
            }
          }]
        }
        rc.should fail(400, 'Missing entry data scope')
      end

      it "should reject CREATE with no data" do
        rc = api_call post "/users/#{@user.id}/journal", {
          account_id: @account.id,
          create: [{
            id: 1234,
            scope: 'account:transactions'
          }]
        }
        rc.should fail(400, 'Missing entry data data')
      end

      it "should reject UPDATE with no shadow" do
        rc = api_call post "/users/#{@user.id}/journal", {
          account_id: @account.id,
          update: [{
            id: 1234,
            scope: 'account:transactions',
            data: {}
          }]
        }
        rc.should fail(400, 'Missing entry data shadow')
      end
    end # Entries
  end # Validation

  context "Processing a Journal" do
    before(:each) do
      @account = @account.refresh
      @account.transactions.destroy
    end

    it "should process an empty journal" do
      rc = api_call post "/users/#{@user.id}/journal", {}
      rc.should succeed
    end

    it "should process a CREATE entry" do
      data = {
        account_id: @account.id,
        create: [{
          id: 1234, # should be discarded
          scope: "account:transactions",
          data: {
            amount: 123,
            type: "deposit"
          }
        }]
      }

      rc = api_call post "/users/#{@user.id}/journal", data
      rc.should succeed
      rc.body["journal"]["errors"].length.should == 0
      @account.refresh.transactions.count.should == 1
    end

    it "should process multiple CREATE entry" do
      data = {
        account_id: @account.id,
        create: [
          {
            id: 2, # should be discarded
            scope: "account:transactions",
            data: {
              amount: 123,
              type: "deposit"
            }
          },
          {
            id: 1, # should be discarded
            scope: "account:transactions",
            data: {
              amount: 10,
              type: "deposit"
            }
          }
        ]
      }

      rc = api_call post "/users/#{@user.id}/journal", data
      rc.should succeed
      rc.body["journal"]["errors"].length.should == 0
      @account.refresh.transactions.count.should == 2
    end

    it "should validate shadow IDs" do
      data = {
        account_id: @account.id,
        create: [
          {
            id: 1234, # should be discarded
            scope: "account:transactions",
            data: {
              amount: 123,
              type: "deposit"
            }
          },
          {
            id: 1234, # should be discarded
            scope: "account:transactions",
            data: {
              amount: 123,
              type: "deposit"
            }
          }
        ]
      }

      rc = api_call post "/users/#{@user.id}/journal", data
      rc.should fail(400, 'Duplicate shadow resource')
    end

    it "should process an UPDATE entry" do
      @transaction = valid! fixture(:deposit, { amount: 5.0 })

      data = {
        account_id: @account.id,
        update: [{
          id: @transaction.id,
          shadow: false,
          scope: "account:transactions",
          data: {
            amount: 10
          }
        }]
      }

      rc = api_call post "/users/#{@user.id}/journal", data
      rc.should succeed
      rc.body["journal"]["errors"].length.should == 0
      @transaction.refresh.amount.to_i.should == 10
    end

    it "should update a shadow entry" do
      data = {
        account_id: @account.id,
        create: [
          {
            id: 1234,
            scope: "account:transactions",
            data: {
              amount: 5,
              type: "deposit"
            }
          }
        ],
        update: [{
          id: 1234,
          shadow: true,
          scope: "account:transactions",
          data: {
            amount: 10
          }
        }]
      }

      rc = api_call post "/users/#{@user.id}/journal", data
      rc.should succeed
      rc.body["journal"]["errors"].length.should == 0
      rc.body["journal"]["processed"]["total"].should == 2
      @account.refresh.transactions.last.amount.to_i.should == 10
    end

    it "should DESTROY an entry" do
      @transaction = valid! fixture(:deposit)

      data = {
        account_id: @account.id,
        destroy: [{
          id: @transaction.id,
          scope: 'account:transactions'
        }]
      }

      rc = api_call post "/users/#{@user.id}/journal", data
      rc.should succeed
      rc.body["journal"]["errors"].length.should == 0
      @account.refresh.transactions.count.should == 0
    end

    it "should not DESTROY a non-existing resource" do
      data = {
        account_id: @account.id,
        destroy: [{
          id: 12341234,
          scope: 'account:transactions'
        }]
      }

      rc = api_call post "/users/#{@user.id}/journal", data
      rc.should succeed
      rc.body["journal"]["errors"].length.should == 1
    end

    it "should not update a resource when a DESTROY entry for it exists" do
      @transaction = valid! fixture(:deposit, { amount: 5.0 })
      data = {
        account_id: @account.id,
        destroy: [{
          id: @transaction.id,
          scope: 'account:transactions'
        }],

        update: [{
          id: @transaction.id,
          scope: 'account:transactions',
          shadow: false,
          data: {
            amount: 1000
          }
        }]
      }

      rc = api_call post "/users/#{@user.id}/journal", data
      rc.should succeed
      rc.body["journal"]["errors"].length.should == 0
      rc.body["journal"]["processed"]["total"].should == 1
      @account.refresh.transactions.count.should == 0
    end

  end
end