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

  it "creating a transaction" do
    data = {
      users: [{
        id: @user.id,
        accounts: [{
          id: @account.id,
          transactions: {
            create: [{
              id: 'c1234',
              data: {
                amount: 5,
                occured_on: '12/31/2013',
                type: 'withdrawal'
              }
            }]
          }
        }]
      }]
    }

    count = @account.transactions.length
    rc = api_call post "/users/#{@user.id}/journal", { entries: data }
    rc.should succeed
    @account.refresh.transactions.length.should == count+1
  end

  it "creating a resource" do
    data = {
      entries: {
        accounts: [{
          id: @account.id,
          transactions: {
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
        users: [{
          id: @user.id,
          categories: {
            create: [{
              id: 'c1234',
              data: {
                name: "My Category"
              }
            }]
          }
        }]
      }
    }

    nr_categories = @user.categories.length
    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    @user.refresh.categories.length.should == nr_categories+1
  end

  it "creating multiple resources" do
    data = {
      entries: {
        accounts: [{
          id: @account.id,
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
        }]
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
      entries: {
        accounts: [{
          id: @account.id,
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
        }]
      }
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should fail(400, 'Duplicate shadow resource')
  end

  it "overwriting a shadow resource" do
    data = {
      entries: {
        accounts: [{
          id: @account.id,
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
        }]
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
      entries: {
        accounts: [{
          id: @account.id,
          transactions: {
            update: [{
              id: @transaction.id,
              data: { amount: 10 }
            }]
          }
        }]
      }
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    rc.body["journal"]["processed"]["account"]["transactions"]["update"].length.should == 1
    @transaction.refresh.amount.to_i.should == 10
  end

  it "updating a shadow entry" do
    data = {
      entries: {
        accounts: [{
          id: @account.id,
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
        }]
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
      entries: {
        accounts: [{
          id: @account.id,
          transactions: {
            delete: [{
              id: @transaction.id
            }]
          }
        }]
      }
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    @account.refresh.transactions.count.should == 0
  end

  it "deleting a non-existing resource" do
    data = {
      entries: {
        accounts: [{
          id: @account.id,
          transactions: {
            delete: [{
              id: 10011111
            }]
          }
        }]
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
      entries: {
        accounts: [{
          id: @account.id,
          transactions: {
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
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    rc.body["journal"]["processed"].length.should == 1
    rc.body["journal"]["dropped"].length.should == 1
    @account.refresh.transactions.count.should == 0
  end

  context "Resources" do
    context "Accounts" do
      it "updating an account" do
        data = {
          entries: {
            users: [{
              id: @user.id,
              accounts: {
                update: [{
                  id: @account.id,
                  data: {
                    currency: "EUR"
                  }
                }]
              }
            }]
          }
        }

        rc = api_call post "/users/#{@user.id}/journal", data
        rc.should succeed
        rc.body["journal"]["processed"]["user"]["accounts"]["update"].length.should == 1
        @account.refresh.currency.should == 'EUR'
      end
    end

    context "Payment Methods" do
      it "creating a pm" do
        data = {
          entries: {
            users: [{
              id: @user.id,
              payment_methods: {
                create: [{
                  id: 'foobar',
                  data: {
                    name: 'Adooken'
                  }
                }]
              }
            }]
          }
        }

        rc = api_call post "/users/#{@user.id}/journal", data
        rc.should succeed
        rc.body["journal"]["processed"]["user"]["payment_methods"]["create"].length.should == 1
      end

      it "updating a pm" do
        pm = @user.payment_methods.create({name: "Adooken2"})

        data = {
          entries: {
            users: [{
              id: @user.id,
              payment_methods: {
                update: [{
                  id: pm.id,
                  data: {
                    name: 'Adooken3'
                  }
                }]
              }
            }]
          }
        }

        rc = api_call post "/users/#{@user.id}/journal", data
        rc.should succeed
        rc.body["journal"]["processed"]["user"]["payment_methods"]["update"].length.should == 1
        pm.refresh.name.should == 'Adooken3'
      end

      it "deleting a pm" do
        pm = @user.payment_methods.first

        data = {
          entries: {
            users: [{
              id: @user.id,
              payment_methods: {
                delete: [{
                  id: pm.id
                }]
              }
            }]
          }
        }

        rc = api_call post "/users/#{@user.id}/journal", data
        rc.should succeed
        rc.body["journal"]["processed"]["user"]["payment_methods"]["delete"].length.should == 1
        pm.refresh.should be_false
      end
    end # Payment Methods

    # context "Categories" do
    #   it "creating a category" do
    #     data = {
    #       scopemap: {
    #       },
    #       entries: {
    #         user: {
    #           categories: {
    #             create: [{
    #               id: 'foobar',
    #               data: {
    #                 name: 'Adooken'
    #               }
    #             }]
    #           }
    #         }
    #       }
    #     }

    #     rc = api_call post "/users/#{@user.id}/journal", data
    #     rc.should succeed
    #     rc.body["journal"]["processed"]["user"]["categories"]["create"].length.should == 1
    #   end

    #   it "updating a category" do
    #     c = @user.categories.create({ name: "Adooken2" })

    #     data = {
    #       scopemap: {
    #       },
    #       entries: {
    #         user: {
    #           categories: {
    #             update: [{
    #               id: c.id,
    #               data: {
    #                 name: 'Adooken3'
    #               }
    #             }]
    #           }
    #         }
    #       }
    #     }

    #     rc = api_call post "/users/#{@user.id}/journal", data
    #     rc.should succeed
    #     rc.body["journal"]["processed"]["user"]["categories"]["update"].length.should == 1
    #     c.refresh.name.should == 'Adooken3'
    #   end

    #   it "deleting a category" do
    #     c = @user.categories.first

    #     data = {
    #       scopemap: {
    #       },
    #       entries: {
    #         user: {
    #           categories: {
    #             delete: [{
    #               id: c.id
    #             }]
    #           }
    #         }
    #       }
    #     }

    #     rc = api_call post "/users/#{@user.id}/journal", data
    #     rc.should succeed
    #     rc.body["journal"]["processed"]["user"]["categories"]["delete"].length.should == 1
    #     c.refresh.should be_false
    #   end
    # end # Categories

    # context "Recurrings" do
    #   it "creating an rtx" do
    #     data = {
    #       scopemap: {
    #         account_id: @account.id
    #       },
    #       entries: {
    #         account: {
    #           recurrings: {
    #             create: [{
    #               id: 'c123',
    #               data: {
    #                 note: "Salary",
    #                 flow_type: "positive",
    #                 amount: 5,
    #                 frequency: "monthly",
    #                 recurs_on_day: 5
    #               }
    #             }]
    #           }
    #         }
    #       }
    #     }

    #     rc = api_call post "/users/#{@user.id}/journal", data
    #     rc.should succeed
    #     rc.body["journal"]["processed"]["account"]["recurrings"]["create"].length.should == 1
    #   end

    #   it "updating a category" do
    #     rtx = valid! fixture(:recurring)

    #     data = {
    #       scopemap: {
    #         account_id: @account.id
    #       },
    #       entries: {
    #         account: {
    #           recurrings: {
    #             update: [{
    #               id: rtx.id,
    #               data: {
    #                 note: "Booyah"
    #               }
    #             }]
    #           }
    #         }
    #       }
    #     }

    #     rc = api_call post "/users/#{@user.id}/journal", data
    #     rc.should succeed
    #     rc.body["journal"]["processed"]["account"]["recurrings"]["update"].length.should == 1
    #     rtx.refresh.note.should == 'Booyah'
    #   end

    #   it "deleting an rtx" do
    #     rtx = valid! fixture(:recurring)

    #     data = {
    #       scopemap: {
    #         account_id: @account.id
    #       },
    #       entries: {
    #         account: {
    #           recurrings: {
    #             delete: [{
    #               id: rtx.id
    #             }]
    #           }
    #         }
    #       }
    #     }

    #     rc = api_call post "/users/#{@user.id}/journal", data
    #     rc.should succeed
    #     rc.body["journal"]["processed"]["account"]["recurrings"]["delete"].length.should == 1
    #     rtx.refresh.should be_false
    #   end
    # end # Categories

    it "updating user" do
      data = {
        entries: {
          users: [{
            id: @user.id,

            users: {
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
      }

      rc = api_call post "/users/#{@user.id}/journal", data
      rc.should succeed
      puts rc.body
      rc.body["journal"]["processed"]["user"]["users"]["update"].length.should == 1
      @user.refresh.p('foo').should == 'bar'
    end
  end

  it "dependent operations" do
    data = {
      entries: {
        users: [{
          id: @user.id,
          accounts: [{
            id: @account.id,
            transactions: {
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
          }],
          categories: {
            create: [{
              id:   'c10443',
              data: {
                name: "Hot hot hot"
              }
            }]
          },

          payment_methods: {
            create: [{
              id: 'c10445',
              data: {
                name: 'Cold'
              }
            }]
          },

          users: {
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
    }

    rc = api_call post "/users/#{@user.id}/journal", data
    rc.should succeed
    puts rc.body

    rc.body["journal"]["processed"]["user"]["users"]["update"].length.should == 1
    rc.body["journal"]["processed"]["user"]["categories"]["create"].length.should == 1
    rc.body["journal"]["processed"]["user"]["payment_methods"]["create"].length.should == 1
    rc.body["journal"]["processed"]["account"]["transactions"]["create"].length.should == 1

    tx_id = rc.body["journal"]["shadowmap"]["account"]["transactions"]["c10444"]
    ca_id = rc.body["journal"]["shadowmap"]["user"]["categories"]["c10443"]
    pm_id = rc.body["journal"]["shadowmap"]["user"]["payment_methods"]["c10445"]

    tx = valid! Transaction.get(tx_id)
    ca = valid! Category.get(ca_id)
    pm = valid! PaymentMethod.get(pm_id)

    tx.categories.length.should == 1
    tx.categories.first.should  == ca
    tx.payment_method.should == pm
  end

end