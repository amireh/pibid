namespace :pibi do
  namespace :recurrings do
    desc "commits all applicable recurring transactions"
    task :commit => :outstanding do
      puts "Committing..."

      nr_committed = 0
      nr_outstanding = 0

      Recurring.all.select { |rtx| rtx.active? }.each { |rtx|
        occurrences = rtx.all_occurrences
        occurrences.length.times do
          if rtx.commit
            nr_committed += 1
          end

          rtx = rtx.refresh
        end

        nr_outstanding += occurrences.length
      }

      puts "Committed #{nr_committed} out of #{nr_outstanding} outstanding bills."
    end

    task :corrupt => :environment do
      corrupt = Recurring.all.select { |tx|
        r = tx.recurs_on
        r.year == 0 || r.month == 0 || r.day == 0
      }

      puts "There are #{corrupt.length} corrupt recurrings, id map: "
      puts corrupt.map(&:id).inspect
    end

    task :fix_corrupt => :corrupt do
      corrupt = Recurring.all.select { |tx|
        r = tx.recurs_on
        r.year == 0 || r.month == 0 || r.day == 0
      }

      fixed = 0

      corrupt.each do |tx|
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

      puts "#{corrupt.length - still_bad.length} recurrings were fixed out of #{corrupt.length}."
    end

    desc "Outstanding recurrings that are due."
    task :outstanding => :environment do
      # outstanding = Recurring.all.select { |r| r.due? || !r.all_occurrences.empty? }
      count = 0
      outstanding = Recurring.all
      outstanding.each do |rtx|
        occurrences = rtx.all_occurrences

        if !rtx.due? && occurrences.empty?
          next
        end

        if !rtx.active?
          next
        end

        count += 1

        puts "Recurring##{rtx.id} '#{rtx.note}' (#{rtx.frequency}):"

        if rtx.due?
          puts "  is due on #{rtx.next_billing_date}"
        end

        if !occurrences.empty?
          puts "  has #{occurrences.length} outstanding occurrences:"
          for i in (0..occurrences.length-1) do
            puts "\t\t#{i} -> #{occurrences[i]}"
          end
        end
      end
      puts "Total recurrings: #{Recurring.all.length}"
      puts "Total outstanding recurrings: #{count}"
    end

  end
end
