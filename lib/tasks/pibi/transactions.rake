namespace :pibi do
  namespace :transactions do
    desc 'converts all timestamps to UTC'
    task :to_utc => :environment do
      def to_utc(d)
        ( Time.at(d.to_i).utc + d.utc_offset ).utc
      end

      transies = Transaction.all.select { |t| t.occured_on.utc_offset != 0 }

      puts "Fixing #{transies.count} transactions."
      transies.each do |tx|
        occurence = tx.occured_on
        creation = tx.created_at

        tx.update({
          occured_on: to_utc( occurence ),
          created_at: to_utc( creation )
        })
      end

      puts "Fixed."
    end

    desc 'the transactions that are not UTC timestamped'
    task :non_utc => :environment do
      puts "Number of transactions that are not stamped as UTC:"
      puts Transaction.all.select { |t| t.occured_on.utc_offset != 0 }.count

      puts "Offsets from UTC:"
      puts Transaction.all.map { |t| t.occured_on.utc_offset }.uniq
    end
  end
end