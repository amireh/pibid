require 'money'
require 'money/bank/google_currency'
require 'money/bank/open_exchange_rates_bank'

namespace :pibi do
  namespace :currencies do
    # desc "populates the currency table"
    # task :populate => :environment do
    #   puts "[pibi:currencies] retrieving latest exchange rates from Google Currencies..."

    #   bank = Money.default_bank = Money::Bank::GoogleCurrency.new
    #   bank.flush_rates

    #   puts "[pibi:currencies] #{Money::Currency.table.length} currencies retrieved, populating..."
    #   Currency.destroy
    #   Money::Currency.table.each { |centry|
    #     begin;
    #       iso  = centry[1][:iso_code]
    #       symbol = centry[1][:symbol]
    #       rate = 1.to_money( iso ).exchange_to(:USD).dollars
    #       next if rate <= 0.0

    #       c = Currency.create({
    #         name:   iso,
    #         rate:   (1 / rate).round(2),
    #         symbol: symbol
    #       })

    #       puts "Currency: #{c.name} => #{c.rate}"

    #     rescue Money::Bank::UnknownRate => e;
    #     end
    #   }
    #   puts "[pibi:currencies] #{Currency.count} currencies registered"
    # end

    desc "updates the currency exchange rates"
    task :update => :environment do
      puts "Retrieving latest exchange rates from Open Exchange Rates..."

      bank = Money.default_bank = Money::Bank::OpenExchangeRatesBank.new
      bank.cache = File.join($ROOT, 'tmp', 'oer_currencies.json')
      bank.app_id = settings.oer['app_id']
      bank.update_rates

      list = bank.doc["rates"]

      puts "#{list.length} currencies retrieved, updating exchange rates..."

      # Make sure USD is there
      Currency.first_or_create({ name: 'USD' }, { rate: 1.0 })

      list.each_pair do |iso_code, rate|
        symbol = iso_code

        # next if (1 / rate.to_f).round(2) <= 0.0
        next if !rate

        # look up the symbol, if possible
        begin
          symbol = Money::Currency.find(iso_code).symbol
        rescue Exception => e
        end

        symbol ||= iso_code

        c = Currency.first_or_create({ name: iso_code }, { rate: 1 })
        c.update!({ rate: rate, symbol: symbol[0..2] })
      end

      # Money::Currency.table.each do |centry|
      #   begin
      #     iso     = centry[1][:iso_code]
      #     symbol  = centry[1][:symbol]
      #     rate    = 1.to_money( iso ).exchange_to(:USD).dollars

      #     next if rate <= 0.0

      #     if c = Currency.first_or_create({ name: iso }, { rate: 1 })
      #       c.update!({ rate: (1 / rate).round(2) })
      #     end

      #     puts "Currency: #{c.name} => #{c.rate}"
      #   rescue Exception => e;
      #     puts "Error!"
      #     puts "Currency entry: #{centry}"
      #     puts "Exception: #{e.inspect}"
      #   end
      # end

      puts "Currency exchange rates have updated, #{Currency.count} currencies available."
    end

    desc 'the number of currencies with invalid rate'
    task :invalid => :environment do
      puts Currency.all({ rate: 0 }).map(&:name)
    end

    desc 'remove invalid currencies'
    task :remove_invalid => :environment do
      Currency.all({ rate: 0 }).each do |c|
        transies = Transaction.all({ currency: c.name })
        transies.each do |tx|
          tx.update({
            currency: 'USD',
            currency_rate: 1
          })
        end

        puts "Adjusted #{transies.length} transactions to use USD instead of #{c.name}"
      end

      Currency.all({ rate: 0 }).destroy
    end
  end
end
