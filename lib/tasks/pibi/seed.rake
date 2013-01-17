namespace :pibi do
  desc "seeds the given user with some random data for testing"
  task :seed, [ :user_id, :year ] => :environment do |t, args|
    user_id, year = args[:user_id], args[:year]

    unless u = User.get(user_id)
      raise ArgumentError.new("No such user with id #{user_id}")
    end

    @year = year

    u.categories.first_or_create({ name: 'Food' })
    u.categories.first_or_create({ name: 'Utility' })
    u.categories.first_or_create({ name: 'Merchandise' })
    u.categories.first_or_create({ name: 'Gaming' })
    u.categories.first_or_create({ name: 'Shopping' })
    u.categories.first_or_create({ name: 'Salary' })
    u.categories.first_or_create({ name: 'Gifts' })

    def rand_currency()
      currencies = Currency.all_names
      currencies[rand(currencies.length)]
    end

    def rand_date()
      Time.new(@year, rand(11) + 1, rand(26) + 1)
    end

    # some withdrawals
    for i in 0..25 do
      tx = u.accounts.first.withdrawals.create({
        amount: rand(1000) + 1,
        currency: rand_currency(),
        occured_on: rand_date
      })
      tx.categories << u.categories[rand(4)]
      tx.save
    end

    for i in 0..25 do
      tx = u.accounts.first.deposits.create({
        amount: rand(1000) + 1,
        currency: rand_currency(),
        occured_on: rand_date
      })
      tx.categories << u.categories[rand(2) + 4]
      tx.save
    end

  end
end
