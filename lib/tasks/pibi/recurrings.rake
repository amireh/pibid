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

  task :bad_recurrings => :environment do
    baddies = Recurring.all.select { |tx|
      r = tx.recurs_on
      r.year == 0 || r.month == 0 || r.day == 0
    }

    puts "There are #{baddies.length} bad recurrings, id map: "
    puts baddies.map(&:id).inspect
  end


  task :fix_bad_recurrings => :environment do
    baddies = Recurring.all.select { |tx|
      r = tx.recurs_on
      r.year == 0 || r.month == 0 || r.day == 0
    }

    fixed = 0

    baddies.each do |tx|
      r = tx.recurs_on
      year = r.year == 0 ? Time.now.year : r.year
      month = r.month == 0 ? 1 : r.month
      day = r.day == 0 ? 1 : r.day

      f = DateTime.new(year, month, day)

      puts r.year
      puts "New date: #{f}"

      tx.refresh.update!({ recurs_on: f })
    end

    still_bad = Recurring.all.select { |tx|
      r = tx.recurs_on
      r.year == 0 || r.month == 0 || r.day == 0
    }

    puts "#{baddies.length - still_bad.length} recurrings were fixed out of #{baddies.length}."
  end


end
