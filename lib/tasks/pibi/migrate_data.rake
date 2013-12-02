# $data_path = File.join(File.dirname(__FILE__), 'pibi')

namespace :pibi do
  desc "migrate from the live pibi data to the new structure"
  task :migrate, [ :path ] => [ :environment ] do |t, args|
    path = args[:path]
    raise ArgumentError.new "Missing path to MongoDB JSON collection dumps" if !path || path.empty?

    json = {}

    # migrate the users
    def name_from_email(email)
      email.split('@').first.sanitize
    end

    puts "Cleaning up old records."

    User.destroy

    errors = []
    json[:users] = JSON.parse(File.read(        File.join(path, 'pibi_users.json')))
    json[:stashes] = JSON.parse(File.read(      File.join(path, 'pibi_stashes.json')))
    json[:tags] = JSON.parse(File.read(         File.join(path, 'pibi_tags.json')))
    json[:transactions] = JSON.parse(File.read( File.join(path, 'pibi_transactions.json')))
    i = 0
    json[:users].each { |r|
      next if r['email'].include? 'tester'
      # break if i == 1
      # i += 1

      some_salt = Pibi.salt
      u = User.create({
        provider:               'pibi',
        email:                  r['email'],
        name:                   name_from_email(r['email']),
        password:               User.encrypt(some_salt),
        password_confirmation:  User.encrypt(some_salt),
        auto_password:          true
      })

      locate_account = lambda { |oid|
        json[:stashes].each { |sr|
          if sr['user_id']['$oid'] == oid then return sr end
        }
        nil
      }

      raise RuntimeError.new "#{u.all_errors}" unless u

      # update the account (we don't update the balance as it will be automatically
      # calculated when migrating the transactions)
      account_record = locate_account.call(r['_id']['$oid'])
      a = u.accounts.first
      a.update({
        label: account_record['name'],
        currency: account_record['currency']
      })
      a.save

      puts "Account: #{a.label}, (#{a.balance} #{a.currency})"

      # create the categories (called tags)
      tags = {}
      puts "Categories: "
      json[:tags].each { |tr|
        # skip tags not belonging to this account
        next unless tr['stash_id']['$oid'] == account_record['_id']['$oid']

        # create the tag & track it so we can attach txs to it later
        begin
          c = u.categories.first_or_create({ name: tr['name'] })
          tags[tr['_id']['$oid']] = c

          puts "\t#{c.name}"
        rescue Exception => e
          puts "\t>> Unable to migrate: #{tr['name']} -- #{e.message} <<"
        end
      } # tag loop

      # finally, the transactions
      json[:transactions].each { |txr|
        # skip transactions not belonging to this account
        next unless txr['stash_id']['$oid'] == account_record['_id']['$oid']

        # is it a withdrawal or a deposit?
        # (keep in mind, recurring txs weren't implemented in the earlier version)
        # collection = case txr['type']
        #   when 'withdrawal' then Withdrawal
        #   when 'deposit'    then Deposit
        # end
        if !txr['type'] || txr['type'].empty?
          errors << ">> ERROR: invalid TX record, missing 'type': #{txr}"
          puts errors.last
          next
        end

        collection = a.send("#{txr['type']}s")

        tx = collection.create({
          account:    a,
          amount:     txr['amount'],
          currency:   txr['currency'],
          note:       txr['note'],
          occured_on: Time.at(txr['created_at']['$date'] / 1000)
        })

        raise RuntimeError.new "Unable to save transaction: #{txr.inspect}" unless tx.saved?

        # puts tx.inspect

        # now we need to connect the tags/categories by looking up
        # each tag id referenced by this tx in the tags hash we created
        # above
        # puts "\t\tLinking tx to ##{txr['tag_ids'].size} categories"
        txr['tag_ids'].each { |tag_id|
          tx = tx.refresh
          c = tags[ tag_id['$oid'] ]
          if c
            tx.categories << c
            tx.save
          end
        }

        # tx.save

        if tx.categories.size != txr['tag_ids'].size then
          puts  ">> Transaction was supposed to be attached to ##{txr['tag_ids'].size}" +
                " categories, but was instead attached to ##{tx.categories.size} <<"
        end

        a = a.refresh
        puts "\t\t#{tx.type} -> #{tx.amount.to_f} #{tx.categories.collect { |c| c.name }} (#{tx.id})"
      }

      puts "#txs: #{a.transactions.count}"
      puts "#cats: #{u.categories.count}"
      puts "account: #{a.label}, (#{a.balance} #{a.currency})"
      puts "------"
    }

    puts "#errors: #{errors.size}"
    puts errors.join("\n")
    # migrate accounts
  end

  desc 'recurrences to use daily/weekly/monthly/yearly with IceCube'
  task :migrate_recurrences_to_icecube => :environment do
    class Recurring
      property :recurs_on, DateTime
    end

    transactions = Recurring.all
    transactions.each do |t|
      case t.frequency
      when :yearly
        t.update!({
          yearly_day: t.recurs_on.day,
          yearly_months: [ t.recurs_on.month ]
        })
      when :monthly
        t.update!({
          monthly_days: [ t.recurs_on.day ]
        })
      end
    end
  end

  desc 'remove duplicate transactions'
  task :remove_duplicate_transactions => :environment do
    require 'ruby-progressbar'

    erratic = []
    skip = []
    puts "Looking up erratic transactions..."

    transactions = Transaction.all({
      conditions: {
        :created_at.gte => 1.week.ago
      },
      order: [ :created_at.asc ]
    })

    progress_bar = ProgressBar.create({
      title: 'Transactions',
      total: transactions.length,
      format: '%t %E [%B] %p%%'
    })

    transactions.each_with_index do |tx, idx|
      next if skip.include?(tx.id)

      progress_bar.increment

      # duplicates = transactions.select do |rhs|
      #   rhs.id != tx.id &&
      #   rhs.amount == tx.amount &&
      #   rhs.currency == tx.currency &&
      #   rhs.occured_on == tx.occured_on &&
      #   rhs.note == tx.note
      # end
      duplicates = Transaction.all({
        :id.not => tx.id,
        :amount => tx.amount,
        :currency => tx.currency,
        :occured_on => tx.occured_on,
        :note => tx.note
      })

      duplicates = duplicates.map(&:id)

      unless duplicates.empty?
        skip += duplicates
        # transactions.delete_if { |rhs| duplicates.include?(rhs.id) }
        erratic << { transaction: tx, duplicate_ids: duplicates }
      end
    end

    progress_bar.finish

    puts "There are #{erratic.length} erratic transactions."

    puts "First erratic transaction was committed at: #{erratic.first[:transaction].created_at.strftime('%D')}"
    puts "Last erratic transaction was committed at: #{erratic.last[:transaction].created_at.strftime('%D')}"

    all_duplicates = erratic.map { |entry| entry[:duplicate_ids] }.flatten

    progress_bar = ProgressBar.create({
      title: 'Destroying...',
      total: all_duplicates.length,
      format: '%t %E [%B] %p%%'
    })

    erratic.each_with_index do |entry, idx|
      puts "#{idx} --"
      tx = entry[:transaction].reload
      duplicate_ids = entry[:duplicate_ids]

      puts "\tUser: #{tx.account.user.email}"
      puts "\t[#{tx.id}] #{tx.created_at.strftime('%D')} -> #{tx.occured_on.strftime('%D')}"
      puts "\t#{duplicate_ids.length} duplicates: #{duplicate_ids.join(', ')}"

      duplicate_ids.each do |duplicate_id|
        duplicate = Transaction.get(duplicate_id)

        begin
          duplicate.destroy
        rescue Exception => e
          puts "Transaction #{duplicate_id} failed to destroy: #{e.message}"
        end

        progress_bar.increment
      end
    end

    puts "Duplicate IDs:"
    puts all_duplicates.inspect
  end
end
