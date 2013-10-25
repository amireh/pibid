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
    rc = api_call post "/users/#{@user.id}/journals", { records: [] }
    rc.should succeed
  end

  context "Validation" do
    it "bad records" do
      rc = api_call post "/users/#{@user.id}/journals", { records: 123 }
      rc.should fail(400, "Record listing must be of type Array")

      rc = api_call post "/users/#{@user.id}/journals", { records: {} }
      rc.should fail(400, "Record listing must be of type Array")

      rc = api_call post "/users/#{@user.id}/journals", { records: true }
      rc.should fail(400, "Record listing must be of type Array")
    end

    it "bad scope" do
      data = {
        records: [{
          collection: 'hello',
          scope: 'foobar',
          scope_id: @user.id
        }]
      }

      rc = api_call post "/users/#{@user.id}/journals", data
      rc.should fail(400, "Unknown scope")
    end

    it "bad scope identifier" do
      data = {
        records: [{
          collection: 'hello',
          scope: 'user',
          scope_id: 'asdf'
        }]
      }

      rc = api_call post "/users/#{@user.id}/journals", data
      rc.should fail(400, "No such resource")
    end

    it "bad collection" do
      data = {
        records: [{
          collection: 'hello',
          scope: 'user',
          scope_id: @user.id
        }]
      }

      rc = api_call post "/users/#{@user.id}/journals", data
      rc.should fail(400, "No such collection")
    end

    it "bad operations" do
      data = {
        records: [{
          collection: 'accounts',
          scope: 'user',
          scope_id: @user.id,
          operations: []
        }]
      }

      rc = api_call post "/users/#{@user.id}/journals", data
      rc.should fail(400, ".*")

      data = {
        records: [{
          collection: 'accounts',
          scope: 'user',
          scope_id: @user.id,
          operations: true
        }]
      }

      rc = api_call post "/users/#{@user.id}/journals", data
      rc.should fail(400, ".*")
    end

    it "an unknown operation" do
      data = {
        records: [{
          collection: 'accounts',
          scope: 'user',
          scope_id: @user.id,
          operations: {
            foobar: []
          }
        }]
      }

      rc = api_call post "/users/#{@user.id}/journals", data
      rc.should fail(400, "Unrecognized operation")
    end

    it "a bad CREATE operation entry" do
      data = {
        records: [{
          collection: 'accounts',
          scope: 'user',
          scope_id: @user.id,
          operations: {
            create: [{
            }]
          }
        }]
      }

      rc = api_call post "/users/#{@user.id}/journals", data
      rc.should fail(400, "Missing required")

      data = {
        records: [{
          collection: 'accounts',
          scope: 'user',
          scope_id: @user.id,
          operations: {
            create: true
          }
        }]
      }

      rc = api_call post "/users/#{@user.id}/journals", data
      rc.should fail(400, ".*")

      data = {
        records: [{
          collection: 'accounts',
          scope: 'user',
          scope_id: @user.id,
          operations: {
            create: {
              id: 'asdf',
              data: []
            }
          }
        }]
      }

      rc = api_call post "/users/#{@user.id}/journals", data
      rc.should fail(400, ".*")
    end

  end

  it "creating a resource" do
    data = {
      records: [{
        collection: 'transactions',
        scope: 'account',
        scope_id: @account.id,
        operations: {
          create: [{
            id: 'c1234',
            data: {
              amount: 123,
              type: "deposit"
            }
          }]
        }
      }]
    }

    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should succeed
    @account = @account.refresh
    @account.transactions.count.should == 1
    t = @account.transactions.first
    t.id.should == rc.body["journal"]["shadowmap"]["account"][@account.id.to_s]["transactions"]["c1234"]
  end

  it "creating a user-scoped collection resource" do
    data = {
      records: [{
        collection: 'categories',
        scope: 'user',
        scope_id: @user.id,
        operations: {
          create: [{
            id: 'c1234',
            data: {
              name: "My Category"
            }
          }]
        }
      }]
    }

    nr_categories = @user.categories.length
    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should succeed
    @user.refresh.categories.length.should == nr_categories+1
  end

  it "creating multiple resources" do
    data = {
      records: [{
        scope: 'account',
        scope_id: @account.id,
        collection: 'transactions',
        operations: {
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
      }]
    }

    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should succeed
    rc.body["journal"]["processed"]["account"][@account.id.to_s]["transactions"]["create"].length.should == 2
    rc.body["journal"]["shadowmap"]["account"][@account.id.to_s]["transactions"].length.should == 2
    @account.refresh.transactions.count.should == 2
  end

  it "creating multiple resources in different scopes" do
    account1 = valid! fixture(:account)
    account2 = valid! fixture(:account)

    data = {
      records: [{
        scope: 'account',
        scope_id: account1.id,
        collection: 'transactions',
        operations: {
          create: [{
            id: 'c1234',
            data: {
              amount: 123,
              type: "deposit"
            }
          }]
        }
      }, {
        scope: 'account',
        scope_id: account2.id,
        collection: 'transactions',
        operations: {
          create: [{
            id: 'c1235',
            data: {
              amount: 456,
              type: "deposit"
            }
          }]
        }
      }]
    }

    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should succeed
    puts rc.body
    rc.body["journal"]["processed"]["account"][account1.id.to_s]["transactions"]["create"].length.should == 1
    rc.body["journal"]["processed"]["account"][account2.id.to_s]["transactions"]["create"].length.should == 1
  end

  it "duplicate shadow resources" do
    data = {
      graceful: false,
      records: [{
        scope: 'account',
        scope_id: @account.id,
        collection: 'transactions',
        operations: {
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
      }]
    }

    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should fail(400, 'Duplicate shadow resource')
  end

  it "overwriting a shadow resource" do
    data = {
      records: [{
        scope_id: @account.id,
        scope: 'account',
        collection: 'transactions',
        operations: {
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
      }]
    }

    count = @account.refresh.transactions.count

    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should succeed
    @account.refresh.transactions.count.should == count + 1
    @account.refresh.transactions.first.amount.should == 456
  end

  it "updating a resource" do
    @transaction = valid! fixture(:deposit, { amount: 5.0 })

    data = {
      records: [{
        scope_id: @account.id,
        scope: 'account',
        collection: 'transactions',
        operations: {
          update: [{
            id: @transaction.id,
            data: { amount: 10 }
          }]
        }
      }]
    }

    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should succeed
    rc.body["journal"]["processed"]["account"][@account.id.to_s]["transactions"]["update"].length.should == 1
    @transaction.refresh.amount.to_i.should == 10
  end

  it "updating a shadow entry" do
    data = {
      records: [{
          scope_id: @account.id,
          scope: 'account',
        collection: 'transactions',
        operations: {
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
      }]
    }

    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should succeed
    rc.body["journal"]["processed"]["account"][@account.id.to_s]["transactions"]["create"].length.should == 1
    rc.body["journal"]["processed"]["account"][@account.id.to_s]["transactions"]["update"].length.should == 1
    @account.refresh.transactions.last.amount.to_i.should == 10
  end

  it "deleting a resource" do
    @transaction = valid! fixture(:deposit)

    data = {
      records: [{
        scope_id: @account.id,
        scope: 'account',
        collection: 'transactions',
        operations: {
          delete: [{
            id: @transaction.id
          }]
        }
      }]
    }

    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should succeed
    @account.refresh.transactions.count.should == 0
  end

  it "deleting a non-existing resource" do
    data = {
      records: [{
        scope_id: @account.id,
        scope: 'account',
        collection: 'transactions',
        operations: {
          delete: [{
            id: 10011111
          }]
        }
      }]
    }

    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should succeed
    rc.body["journal"]["processed"].should be_empty
    rc.body["journal"]["dropped"].length.should == 1
  end

  it "updating a deleted resource" do
    @transaction = valid! fixture(:deposit, { amount: 5.0 })
    data = {
      records: [{
        scope_id: @account.id,
        scope: 'account',
        collection: 'transactions',
        operations: {
          update: [{
            id: @transaction.id,
            data: { amount: 5 }
          }],

          delete: [{
            id: @transaction.id
          }]
        }
      }]
    }

    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should succeed
    rc.body["journal"]["processed"].length.should == 1
    rc.body["journal"]["dropped"].length.should == 1
    @account.refresh.transactions.count.should == 0
  end

  context "Resources" do
    context "Accounts" do
      it "updating an account" do
        data = {
          records: [{
            scope_id: @user.id,
            scope: 'user',
            collection: 'accounts',
            operations: {
              update: [{
                id: @account.id,
                data: {
                  currency: "EUR"
                }
              }]
            }
          }]
        }

        rc = api_call post "/users/#{@user.id}/journals", data
        rc.should succeed
        rc.body["journal"]["processed"]["user"][@user.id.to_s]["accounts"]["update"].length.should == 1
        @account.refresh.currency.should == 'EUR'
      end
    end

    context "Payment Methods" do
      it "creating a pm" do
        data = {
          records: [{
            scope_id: @user.id,
            scope: 'user',
            collection: 'payment_methods',
            operations: {
              create: [{
                id: 'foobar',
                data: {
                  name: 'Adooken'
                }
              }]
            }
          }]
        }

        rc = api_call post "/users/#{@user.id}/journals", data
        rc.should succeed
        rc.body["journal"]["processed"]["user"][@user.id.to_s]["payment_methods"]["create"].length.should == 1
      end

      it "updating a pm" do
        pm = @user.payment_methods.create({name: "Adooken2"})

        data = {
          records: [{
            scope_id: @user.id,
            scope: 'user',
            collection: 'payment_methods',
            operations: {
              update: [{
                id: pm.id,
                data: {
                  name: 'Adooken3'
                }
              }]
            }
          }]
        }

        rc = api_call post "/users/#{@user.id}/journals", data
        rc.should succeed
        rc.body["journal"]["processed"]["user"][@user.id.to_s]["payment_methods"]["update"].length.should == 1
        pm.refresh.name.should == 'Adooken3'
      end

      it "deleting a pm" do
        pm = @user.payment_methods.first

        data = {
          records: [{
            scope: 'user',
            scope_id: @user.id,
            collection: 'payment_methods',
            operations: {
              delete: [{
                id: pm.id
              }]
            }
          }]
        }

        rc = api_call post "/users/#{@user.id}/journals", data
        rc.should succeed
        rc.body["journal"]["processed"]["user"][@user.id.to_s]["payment_methods"]["delete"].length.should == 1
        pm.refresh.should be_false
      end
    end # Payment Methods

    context "Categories" do
      before(:each) do
        @user.categories.destroy
      end

      it "creating a category" do
        data = {
          graceful: false,
          records: [{
            collection: 'categories',
            scope: 'user',
            scope_id: @user.id,
            operations: {
              create: [{
                id: 'c1345',
                data: {
                  name: 'Adooken3'
                }
              }]
            }
          }]
        }

        rc = api_call post "/users/#{@user.id}/journals", data
        rc.should succeed
        rc.body["journal"]["processed"]["user"][@user.id.to_s]["categories"]["create"].length.should == 1
      end

      it "updating a category" do
        c = valid! fixture(:category)
        name = "Adooken #{Time.now.utc}"

        data = {
          records: [{
            collection: 'categories',
            scope: 'user',
            scope_id: @user.id,
            operations: {
              update: [{
                id: c.id,
                data: {
                  name: name
                }
              }]
            }
          }]
        }

        rc = api_call post "/users/#{@user.id}/journals", data
        rc.should succeed
        rc.body["journal"]["processed"]["user"][@user.id.to_s]["categories"]["update"].length.should == 1
        c.refresh.name.should == name
      end

      it "deleting a category" do
        c = valid! fixture(:category)

        data = {
          records: [{
            scope: 'user',
            scope_id: @user.id,
            collection: 'categories',
            operations: {
              delete: [{
                id: c.id
              }]
            }
          }]
        }

        rc = api_call post "/users/#{@user.id}/journals", data
        rc.should succeed
        rc.body["journal"]["processed"]["user"][@user.id.to_s]["categories"]["delete"].length.should == 1
        c.refresh.should be_false
      end
    end # Categories

    context "Recurrings" do
      it "creating an rtx" do
        data = {
          records: [{
            scope: 'account',
            scope_id: @account.id,
            collection: 'recurrings',
            operations: {
              create: [{
                id: 'c123',
                data: {
                  note: "Salary",
                  flow_type: "positive",
                  amount: 5,
                  frequency: "monthly",
                  monthly_days: [5]
                }
              }]
            }
          }]
        }

        rc = api_call post "/users/#{@user.id}/journals", data
        rc.should succeed
        rc.body["journal"]["processed"]["account"][@account.id.to_s]["recurrings"]["create"].length.should == 1
      end

      it "updating an rtx" do
        rtx = valid! fixture(:recurring)

        data = {
          records: [{
            scope_id: @account.id,
            scope: 'account',
            collection: 'recurrings',
            operations: {
              update: [{
                id: rtx.id,
                data: {
                  note: "Booyah"
                }
              }]
            }
          }]
        }

        rc = api_call post "/users/#{@user.id}/journals", data
        rc.should succeed
        rc.body["journal"]["processed"]["account"][@account.id.to_s]["recurrings"]["update"].length.should == 1
        rtx.refresh.note.should == 'Booyah'
      end

      it "deleting an rtx" do
        rtx = valid! fixture(:recurring)

        data = {
          records: [{
            scope_id: @account.id,
            scope: 'account',
            collection: 'recurrings',
            operations: {
              delete: [{
                id: rtx.id
              }]
            }
          }]
        }

        rc = api_call post "/users/#{@user.id}/journals", data
        rc.should succeed
        rc.body["journal"]["processed"]["account"][@account.id.to_s]["recurrings"]["delete"].length.should == 1
        rtx.refresh.should be_false
      end
    end # Recurrings

    it "updating user" do
      data = {
        records: [{
          scope_id: @user.id,
          scope: 'user',
          collection: 'users',
          operations: {
            update: [{
              id: @user.id,
              data: {
                preferences: {
                  foo: 'bar'
                }
              }
            }]
          }
        }]
      }

      rc = api_call post "/users/#{@user.id}/journals", data
      rc.should succeed
      puts rc.body
      rc.body["journal"]["processed"]["user"][@user.id.to_s]["users"]["update"].length.should == 1
      @user.refresh.p('foo').should == 'bar'
    end
  end

  it "dependent operations" do
    data = {
      records: [{
        scope: 'account',
        scope_id: @account.id,
        collection: 'transactions',
        operations: {
          create: [{
            id: 'c10444',
            data: {
              amount: 12.24,
              type: 'withdrawal',
              payment_method_id: 'c10445',
              categories: [ 'c10443' ]
            }
          }]
        }
      }, {
        scope: 'user',
        scope_id: @user.id,
        collection: 'categories',
        operations: {
          create: [{
            id:   'c10443',
            data: {
              name: "Hot hot hot"
            }
          }]
        }
      }, {
        scope: 'user',
        scope_id: @user.id,
        collection: 'payment_methods',
        operations: {
          create: [{
            id: 'c10445',
            data: {
              name: 'Cold'
            }
          }]
        }
      }, {
        scope: 'user',
        scope_id: @user.id,
        collection: 'users',
        operations: {
          update: [{
            id: @user.id,
            data: {
              preferences: {
                foo: 'bar'
              }
            }
          }]
        }
      }]
    }

    rc = api_call post "/users/#{@user.id}/journals", data
    rc.should succeed
    puts rc.body

    rc.body["journal"]["processed"]["user"][@user.id.to_s]["users"]["update"].length.should == 1
    rc.body["journal"]["processed"]["user"][@user.id.to_s]["categories"]["create"].length.should == 1
    rc.body["journal"]["processed"]["user"][@user.id.to_s]["payment_methods"]["create"].length.should == 1
    rc.body["journal"]["processed"]["account"][@account.id.to_s]["transactions"]["create"].length.should == 1

    tx_id = rc.body["journal"]["shadowmap"]["account"][@account.id.to_s]["transactions"]["c10444"]
    ca_id = rc.body["journal"]["shadowmap"]["user"][@user.id.to_s]["categories"]["c10443"]
    pm_id = rc.body["journal"]["shadowmap"]["user"][@user.id.to_s]["payment_methods"]["c10445"]

    tx = valid! Transaction.get(tx_id)
    ca = valid! Category.get(ca_id)
    pm = valid! PaymentMethod.get(pm_id)

    tx.categories.length.should == 1
    tx.categories.first.should  == ca
    tx.payment_method.should == pm
  end

end