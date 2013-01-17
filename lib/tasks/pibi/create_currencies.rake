namespace :pibi do
  desc "populates the currency table"
  task :currencies => :environment do
    Currency.create({ :name => "USD", :rate => 1.00  })
    Currency.create({ :name => "EUR", :rate => 0.75  })
    Currency.create({ :name => "GBP", :rate => 0.63  })
    Currency.create({ :name => "JPY", :rate => 81.41 })
    Currency.create({ :name => "JOD", :rate => 0.70  })
  end
end
