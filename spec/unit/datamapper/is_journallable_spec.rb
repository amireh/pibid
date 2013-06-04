describe DataMapper::Model do
  it "looking up a shadow" do
    u = valid! fixture(:user)
    c = valid! fixture(:category)

    c = Category.get(c.id)
    c.should be_true

    Category.shadow('c123', c)
    Category.get('c123').should be_true

    tx = valid! fixture(:deposit, {
      amount: 5,
      categories: [ 'c123' ]
    })

    tx.categories.length.should == 1
    tx.categories.first.id.should == c.id
  end

  it "looking up a shadow inside a collection" do
    u = valid! fixture(:user)
    c = valid! fixture(:category)

    c = Category.get(c.id)
    c.should be_true

    Category.shadow('c123', c)
    Category.get('c123').should be_true

    tx = valid! fixture(:deposit, {
      amount: 5,
      categories: [ 'c123' ]
    })

    tx.categories.get('c123').should == c
  end
end