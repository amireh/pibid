require 'money'
require 'money/bank/google_currency'

namespace :pibi do
  desc "populates the currency table"
  task :currencies => :environment do
    # Currency.create({ :name => "USD", :rate => 1.00, symbol: '$' })

    puts "[pibi:currencies] retrieving latest exchange rates from Google Currencies..."

    bank = Money.default_bank = Money::Bank::GoogleCurrency.new
    bank.flush_rates

    puts "[pibi:currencies] retrived, populating..."
    Currency.destroy
    Money::Currency.table.each { |centry|
      begin;
        iso  = centry[1][:iso_code]
        symbol = centry[1][:symbol]
        rate = 1.to_money( iso ).exchange_to(:USD).dollars
        next if rate <= 0.0
        # rate = 1.to_money( :USD ).exchange_to(iso).dollars

        c = Currency.create({
          name:   iso,
          rate:   (1 / rate).round(2),
          symbol: symbol
        })

      rescue Money::Bank::UnknownRate => e;
      # rescue Money::Bank::UnknownCurrency => e;
      end
    }
    puts "[pibi:currencies] #{Currency.count} currencies registered"
  end
end
