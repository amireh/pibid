namespace :pibi do
  desc "set transaction currency rates for those that don't have it"
  task :tx_currency_rates => :environment do
    transies = Transaction.all({ currency_rate: nil })

    puts "Fixing #{transies.count} transies"

    transies.each do |tx|
      tx.update!({ currency_rate: Currency[tx.currency].rate })
    end
  end
end
