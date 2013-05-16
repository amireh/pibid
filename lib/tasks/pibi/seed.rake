namespace :pibi do
  desc "seeds the given user with some random data for testing"
  task :seed, [ :user_id, :year, :nr_transies ] => :environment do |t, args, nr_transies|
    user_id, year, nr_transies = args[:user_id], args[:year], args[:nr_transies].to_i || 25

    unless u = User.get(user_id)
      raise ArgumentError.new("No such user with id #{user_id}")
    end

    @year = year

    def rand_currency()
      currencies = Currency.all_names
      currencies[rand(currencies.length)]
    end

    def rand_date()
      DateTime.new(@year.to_i, rand(11) + 1, rand(26) + 1)
    end

    nr_categories = u.categories.length

    # some withdrawals
    for i in 0..nr_transies do
      tx = u.accounts.first.withdrawals.create({
        amount: rand(1000) + 1,
        currency: rand_currency(),
        occured_on: rand_date
      })
      tx.categories << u.categories[rand(nr_categories)]
      tx.save
    end

    for i in 0..nr_transies do
      tx = u.accounts.first.deposits.create({
        amount: rand(1000) + 1,
        currency: rand_currency(),
        occured_on: rand_date
      })
      tx.categories << u.categories[rand(nr_categories)]
      tx.save
    end

  end

  task :demo => :environment do
    User.create({
      name: "Pibi Demo",
      provider: 'pibi',
      email: 'demo@pibiapp.com',
      password: 'pibidemo123',
      password_confirmation: 'pibidemo123'
    })
  end
end
