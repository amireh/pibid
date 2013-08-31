require 'money'
require 'money/bank/google_currency'

namespace :pibi do
  namespace :currencies do
    desc "populates the currency table"
    task :populate => :environment do
      puts "[pibi:currencies] retrieving latest exchange rates from Google Currencies..."

      bank = Money.default_bank = Money::Bank::GoogleCurrency.new
      bank.flush_rates

      puts "[pibi:currencies] #{Money::Currency.table.length} currencies retrieved, populating..."
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

          puts "Currency: #{c.name} => #{c.rate}"

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

      puts "[pibi:currencies] #{Money::Currency.table.length} currencies retrieved, updating..."
      Money::Currency.table.select { |entry| entry.to_s == 'USD' }.each { |centry|
        iso     = centry[1][:iso_code]
        symbol  = centry[1][:symbol]

        Currency.first_or_create({ name: iso }, {
          rate: 1.0
        })
      }

      Money::Currency.table.each { |centry|
        begin
          iso     = centry[1][:iso_code]
          symbol  = centry[1][:symbol]
          rate    = 1.to_money( iso ).exchange_to(:USD).dollars

          next if rate <= 0.0

          if c = Currency.first_or_create({ name: iso }, { rate: 1 })
            c.update!({ rate: (1 / rate).round(2) })
          end

          puts "Currency: #{c.name} => #{c.rate}"
        rescue Money::Bank::UnknownRate => e;
          puts "Error!"
          puts "Currency entry: #{centry}"
          puts "Exception: #{e.inspect}"
        end
      }
      puts "[pibi:currencies] #{Currency.count} currencies updated."
    end
  end
end
