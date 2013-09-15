namespace :pibi do
  namespace :stats do
    desc 'transactions tagged with multiple categories'
    task :multiple_categories => :environment do
      transies = Transaction.all.select { |tx| tx.categories.length > 1 }
      transies_ratio = transies.length.to_f / Transaction.count * 100

      users = transies.map { |tx| tx.account.user }.uniq
      users_ratio = users.length.to_f / User.count * 100

      ratio = {}
      transies.map { |tx|
        count = tx.categories.length
        ratio[count] ||= 0
        ratio[count] += 1
      }

      puts "Number of transactions: #{transies.length} (#{transies_ratio}%)"
      puts "Number of related users: #{users.length} (#{users_ratio}%)"
      puts "Ratio of transactions per number of categories:"
      ratio.each_pair do |k,v|
        puts "  #{k} categories: #{v} transactions"
      end
    end
  end
end