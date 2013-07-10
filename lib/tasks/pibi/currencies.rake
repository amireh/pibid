require 'money'
require 'money/bank/google_currency'

namespace :pibi do
  namespace :currencies do
    desc "populates the currency table"
    task :populate => :environment do
      puts "[pibi:currencies] retrieving latest exchange rates from Google Currencies..."

      bank = Money.default_bank = Money::Bank::GoogleCurrency.new
      bank.flush_rates

      puts "[pibi:currencies] retrieved, populating..."
      Currency.destroy
      Money::Currency.table.each { |centry|
        begin;
          iso  = centry[1][:iso_code]
          symbol = centry[1][:symbol]
          rate = 1.to_money( iso ).exchange_to(:USD).dollars
          next if rate <= 0.0

          c = Currency.create({
            name:   iso,
            rate:   (1 / rate).round(2),
            symbol: symbol
          })

        rescue Money::Bank::UnknownRate => e;
        end
      }
      puts "[pibi:currencies] #{Currency.count} currencies registered"
    end

    desc "updates the currency exchange rates"
    task :update => :environment do
      puts "[pibi:currencies] retrieving latest exchange rates from Google Currencies..."

      bank = Money.default_bank = Money::Bank::GoogleCurrency.new
      bank.flush_rates

      puts "[pibi:currencies] retrieved, updating..."
      Money::Currency.table.each { |centry|
        begin
          iso     = centry[1][:iso_code]
          symbol  = centry[1][:symbol]
          rate    = 1.to_money( iso ).exchange_to(:USD).dollars

          next if rate <= 0.0

          if c = Currency.first({ name: iso })
            c.update!({ rate: (1 / rate).round(2) })
          end

        rescue Money::Bank::UnknownRate => e;
        end
      }
      puts "[pibi:currencies] #{Currency.count} currencies updated."
    end
  end
end
