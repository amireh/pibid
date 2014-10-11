namespace :pibi do
  desc "dumps the entire data to stdout as JSON"
  task :dump => :environment do
    def pluck(resource, attrs)
      attrs.each_with_object({}) { |a,h| h[a.to_sym] = resource.send(a) }
    end

    class Writer
      attr_accessor :index, :path, :fragment_size, :padding

      def initialize(path, fragment_size=1024, padding=5)
        self.path = path
        self.index = 0
        self.fragment_size = fragment_size
        self.padding = padding

        FileUtils.mkdir_p(path)
      end

      def save(data, filename)
        data.each_slice(self.fragment_size).to_a.each_with_index do |entries, fragment|
          index = "%0#{self.padding}i" % self.index
          filepath = "#{path}/#{index}-#{filename}-#{fragment}.json"
          puts "Writing #{entries.length} #{filename.singularize} entries to #{filepath}"
          File.write(filepath, { "#{filename}" => entries }.to_json)
          self.index += 1
        end
      end
    end

    user_ids = ENV['USER_IDS']
    path = ENV['OUT'] || "#{$ROOT}/dumps/#{Time.now.strftime("%Y.%m.%d")}"
    writer = Writer.new(path)

    users = if user_ids
      User.all(id: user_ids)
    else
      User.all
    end

    users.map do |user|
      pluck user, %w[
        id name provider uid password email email_verified
        settings auto_password created_at link_id
      ]
    end

    writer.save(users, 'users')

    accounts = users.map(&:accounts).flatten.map do |resource|
      pluck resource, %w[ id label balance currency created_at user_id ]
    end

    writer.save(accounts, 'accounts')

    categories = users.map(&:categories).flatten.map do |resource|
      pluck resource, %w[ id name icon user_id]
    end

    writer.save(categories, 'categories')

    notices = users.map(&:notices).flatten.map do |resource|
      pluck resource, %w[ id salt data created_at accepted_at type status user_id ]
    end

    writer.save(notices, 'notices')

    payment_methods = users.map(&:payment_methods).flatten.map do |resource|
      pluck resource, %w[ id name default color user_id ]
    end

    writer.save(payment_methods, 'payment_methods')

    recurrings = users.map(&:accounts).flatten.map(&:recurrings).flatten.map do |resource|
      pluck resource, %w[
        id
        amount
        currency
        note
        created_at
        account_id
        payment_method_id
        flow_type
        frequency
        last_commit
        active
        every
        weekly_days
        monthly_days
        yearly_months
        yearly_day
     ]
    end

    writer.save(recurrings, 'recurrings')

    transactions = users.map(&:accounts).flatten.map(&:transactions).flatten.map do |resource|
      pluck resource, %w[
        id
        amount
        currency
        note
        type
        occured_on
        created_at
        account_id
        payment_method_id
        recurring_id
     ]
    end

    writer.save(transactions, 'transactions')

    category_transactions = if user_ids
      transactions.map do |transaction|
        CategoryTransaction.all(transaction_id: transaction[:id]).map do |ct|
          pluck ct, %w[ category_id transaction_id ]
        end
      end.flatten
    else
      CategoryTransaction.all.map do |resource|
        pluck resource, %w[ category_id transaction_id ]
      end
    end

    writer.save(category_transactions, 'category_transactions')
  end
end
