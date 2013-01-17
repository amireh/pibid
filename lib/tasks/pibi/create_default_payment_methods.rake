namespace :pibi do
  desc "populates user default payment methods"
  task :payment_methods => :environment do
    User.each { |u|
      if u.payment_methods.empty? then
        u.payment_methods.create({ name: "Cash", default: true })
        u.payment_methods.create({ name: "Cheque" })
      end
    }
  end

  desc "assigns a default payment method to users"
  task :default_payment_method => :environment do
    User.each { |u|
      unless u.payment_method
        u.payment_methods.first.update({ default: true })
      end
    }
  end

  desc "colorzies payment methods"
  task :colorize_payment_methods => :environment do
    PaymentMethod.each { |pm| pm.colorize }
  end
end
