feature "Journaling" do
  before(:all) do
    valid! fixture :user
  end

  before :each do
    sign_in @user
    @account = @account.refresh
    @account.transactions.destroy
  end

  it "doing nothing" do
    rc = api_call post "/users/#{@user.id}/journal", {}
    rc.should succeed
  end

  it "creating a resource" do
    data = {
      scopemap: {
        account_id: @account.id
      },
      entries: {
        account: {
          transactions: {
            create: [{
              id: 'c1234',
              data: {
                amount: 123,
                type: "deposit"
              }
            }]
          }
        }
      }
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    @account = @account.refresh
    @account.transactions.count.should == 1
    t = @account.transactions.first
    t.id.should == rc.body["journal"]["shadowmap"]["account"]["transactions"]["c1234"]
  end

  it "creating a user-scoped collection resource" do
    data = {
      entries: {
        user: {
          categories: {
            create: [{
              id: 'c1234',
              data: {
                name: "My Category"
              }
            }]
          }
        }
      }
    }

    nr_categories = @user.categories.length
    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    @user.refresh.categories.length.should == nr_categories+1
  end

  it "creating multiple resources" do
    data = {
      scopemap: {
        account_id: @account.id
      },
      entries: {
        account: {
          transactions: {
            create: [{
              id: 'c1234',
              data: {
                amount: 123,
                type: "deposit"
              }
            }, {
              id: 'c1235',
              data: {
                amount: 456,
                type: "deposit"
              }
            }]
          }
        }
      }
    }


    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    rc.body["journal"]["processed"]["account"]["transactions"]["create"].length.should == 2
    rc.body["journal"]["shadowmap"]["account"]["transactions"].length.should == 2
    @account.refresh.transactions.count.should == 2
  end

  it "duplicate shadow resources" do
    data = {
      graceful: false,
      scopemap: {
        account_id: @account.id
      },
      entries: {
        account: {
          transactions: {
            create: [{
              id: 'c1234',
              data: {
                amount: 123,
                type: "deposit"
              }
            }, {
              id: 'c1234',
              data: {
                amount: 456,
                type: "deposit"
              }
            }]
          }
        }
      }
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should fail(400, 'Duplicate shadow resource')
  end

  it "overwriting a shadow resource" do
    data = {
      scopemap: {
        account_id: @account.id
      },
      entries: {
        account: {
          transactions: {
            create: [{
              id: 'c1234',
              data: {
                amount: 123,
                type: "deposit"
              }
            }, {
              id: 'c1234',
              data: {
                amount: 456,
                type: "deposit"
              }
            }]
          }
        }
      }
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    @account.refresh.transactions.count.should == 1
    @account.refresh.transactions.first.amount.should == 456
  end

  it "updating a resource" do
    @transaction = valid! fixture(:deposit, { amount: 5.0 })

    data = {
      scopemap: {
        account_id: @account.id
      },
      entries: {
        account: {
          transactions: {
            update: [{
              id: @transaction.id,
              data: { amount: 10 }
            }]
          }
        }
      }
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    rc.body["journal"]["processed"]["account"]["transactions"]["update"].length.should == 1
    @transaction.refresh.amount.to_i.should == 10
  end

  it "updating a shadow entry" do
    data = {
      scopemap: {
        account_id: @account.id
      },
      entries: {
        account: {
          transactions: {
            create: [          {
              id: 'c1234',
              data: {
                amount: 5,
                type: "deposit"
              }
            }],
            update: [{
              id: 'c1234',
              data: {
                amount: 10
              }
            }]
          }
        }
      }
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    rc.body["journal"]["processed"]["account"]["transactions"]["create"].length.should == 1
    rc.body["journal"]["processed"]["account"]["transactions"]["update"].length.should == 1
    @account.refresh.transactions.last.amount.to_i.should == 10
  end

  it "deleting a resource" do
    @transaction = valid! fixture(:deposit)

    data = {
      scopemap: {
        account_id: @account.id
      },
      entries: {
        account: {
          transactions: {
            delete: [{
              id: @transaction.id
            }]
          }
        }
      }
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    @account.refresh.transactions.count.should == 0
  end

  it "deleting a non-existing resource" do
    data = {
      scopemap: {
        account_id: @account.id
      },
      entries: {
        account: {
          transactions: {
            delete: [{
              id: 10011111
            }]
          }
        }
      }
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    rc.body["journal"]["processed"].should be_empty
    rc.body["journal"]["dropped"].length.should == 1
  end

  it "updating a deleted resource" do
    @transaction = valid! fixture(:deposit, { amount: 5.0 })
    data = {
      scopemap: {
        account_id: @account.id
      },
      entries: {
        account: {
          transactions: {
            update: [{
              id: @transaction.id,
              data: { amount: 5 }
            }],

            delete: [{
              id: @transaction.id
            }]
          }
        }
      }
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    rc.body["journal"]["processed"].length.should == 1
    rc.body["journal"]["dropped"].length.should == 1
    @account.refresh.transactions.count.should == 0
  end

end