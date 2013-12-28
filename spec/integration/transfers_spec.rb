require 'rabl'

describe "Transactions" do
  before(:all) do
    valid! fixture(:user)
    valid! fixture(:account, {
      currency: 'JOD'
    })
  end

  before do
    sign_in

    @account1 = @user.accounts.first
    @account2 = @user.accounts.last

    @account1.refresh.transactions.destroy
    @account2.refresh.transactions.destroy
  end

  scenario "Creating a transfer" do
    rc = api_call post "/accounts/#{@account1.id}/transactions", {
      type: "deposit",
      amount: 5,
      to: @account2.id
    }

    rc.should succeed
    @account1.refresh.deposits.count.should == 1
    @account2.refresh.withdrawals.count.should == 1
  end

  scenario 'Updating a transaction should update its spouse' do
    rc = api_call post "/accounts/#{@account1.id}/transactions", {
      type: "deposit",
      amount: 5,
      to: @account2.id
    }

    rc.should succeed

    @account2.refresh.transactions.last.amount.to_f.should == 5

    tx = @account1.refresh.transactions.last

    rc = api_call patch "/accounts/#{@account1.id}/transactions/#{tx.id}", {
      amount: 10
    }

    rc.should succeed
    @account2.refresh.transactions.last.amount.to_f.should == 10
  end

  scenario 'Destroying a transaction should destroy its spouse' do
    rc = api_call post "/accounts/#{@account1.id}/transactions", {
      type: "deposit",
      amount: 5,
      to: @account2.id
    }

    rc.should succeed
    @account2.refresh.transactions.length.should == 1

    tx = @account1.refresh.transactions.last
    rc = api_call delete "/accounts/#{@account1.id}/transactions/#{tx.id}"
    rc.should succeed

    @account2.refresh.transactions.length.should == 0
  end


  context 'through the journal' do
    scenario 'Creating a transfer' do
      rc = api_call post "/users/#{@user.id}/journals", {
        records: [{
          collection: 'transactions',
          scope: 'account',
          scope_id: @account1.id,
          operations: {
            create: [{
              id: 'asdf',
              data: {
                type: "deposit",
                amount: 5,
                to: @account2.id
              }
            }]
          }
        }]
      }

      rc.should succeed
      @account1.refresh.deposits.count.should == 1
      @account2.refresh.withdrawals.count.should == 1
    end

    scenario 'Updating a transfer' do
      rc = api_call post "/users/#{@user.id}/journals", {
        records: [{
          collection: 'transactions',
          scope: 'account',
          scope_id: @account1.id,
          operations: {
            create: [{
              id: 'asdf',
              data: {
                type: "deposit",
                amount: 5,
                to: @account2.id
              }
            }]
          }
        }]
      }

      rc.should succeed

      @account2.refresh.transactions.last.amount.should == 5

      tx = @account1.refresh.transactions.last
      rc = api_call post "/users/#{@user.id}/journals", {
        records: [{
          collection: 'transactions',
          scope: 'account',
          scope_id: @account1.id,
          operations: {
            update: [{
              id: tx.id,
              data: {
                amount: 10
              }
            }]
          }
        }]
      }

      rc.should succeed
      @account2.refresh.transactions.last.amount.should == 10
    end

    scenario 'Deleting a transfer' do
      rc = api_call post "/users/#{@user.id}/journals", {
        records: [{
          collection: 'transactions',
          scope: 'account',
          scope_id: @account1.id,
          operations: {
            create: [{
              id: 'asdf',
              data: {
                type: "deposit",
                amount: 5,
                to: @account2.id
              }
            }]
          }
        }]
      }

      rc.should succeed
      @account2.refresh.transactions.length.should == 1

      tx = @account1.refresh.transactions.last
      rc = api_call post "/users/#{@user.id}/journals", {
        records: [{
          collection: 'transactions',
          scope: 'account',
          scope_id: @account1.id,
          operations: {
            delete: [{
              id: tx.id
            }]
          }
        }]
      }

      rc.should succeed
      @account2.refresh.transactions.length.should == 0
    end

  end

end
