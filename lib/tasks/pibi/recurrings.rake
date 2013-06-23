namespace :pibi do
  desc "commits all applicable recurring transactions"
  task :recurrings => :outstanding do
    puts "Committing..."
    commit_count = 0
    Recurring.each { |rtx|
      occurences = rtx.all_occurences
      occurences.each do |o|
        if rtx.commit(o)
          commit_count += 1
        end

        rtx = rtx.refresh
      end

      rtx = rtx.refresh
      rtx.commit(rtx.next_billing_date({ relative_to: Time.now }))
    }

    puts "Committed #{commit_count} outstanding bills."
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

      puts "New date: #{f}"

      tx.refresh.update!({ recurs_on: f })
    end

    still_bad = Recurring.all.select { |tx|
      r = tx.recurs_on
      r.year == 0 || r.month == 0 || r.day == 0
    }

    puts "#{baddies.length - still_bad.length} recurrings were fixed out of #{baddies.length}."
  end

  desc "Outstanding recurrings that are due."
  task :outstanding => :environment do
    # outstanding = Recurring.all.select { |r| r.due? || !r.all_occurences.empty? }
    count = 0
    outstanding = Recurring.all
    outstanding.each do |rtx|
      occurences = rtx.all_occurences

      if !rtx.due? && occurences.empty?
        next
      end

      count += 1

      puts "Recurring##{rtx.id} '#{rtx.note}' (#{rtx.frequency}):"

      if rtx.due?
        puts "  is due on #{rtx.next_billing_date}"
      end

      if !occurences.empty?
        puts "  has #{occurences.length} outstanding occurences:"
        for i in (0..occurences.length-1) do
          puts "\t\t#{i} -> #{occurences[i].strftime('%D')}"
        end
      end
    end
    puts "Total recurrings: #{Recurring.all.length}"
    puts "Total outstanding recurrings: #{count}"
  end
end
