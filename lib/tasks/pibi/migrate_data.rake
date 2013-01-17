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
end
