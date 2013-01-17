namespace :pibi do
  desc "commits all applicable recurring transactions"
  task :recurrings => :environment do
    applicable_count = 0
    Recurring.each { |tx|
      if tx.commit
        applicable_count += 1
      end
    }
    puts "Committed #{applicable_count} outstanding bills."
  end
end
