namespace :pibi do
  desc "Nullifies the hours, minutes, and seconds of Transaction occurences"
  task :fix_occurence_resolution => :environment do
    transies = Transaction.all({ :type.not => Recurring }).select { |tx|
      tx.occured_on.hour != 0 ||
      tx.occured_on.minute != 0 ||
      tx.occured_on.second != 0
    }

    puts "#{transies.length} transactions need fixing."
    nr_fixed = 0

    transies.each do |tx|
      if tx.update({ occured_on: tx.enforce_occurence_resolution })
        nr_fixed += 1
      else
        puts "From #{tx.occured_on} to #{fixed}"
        puts tx.errors
        raise "Unable to fix transaction #{tx.id}"
      end
    end

    puts "#{nr_fixed} transactions fixed."
  end
end
