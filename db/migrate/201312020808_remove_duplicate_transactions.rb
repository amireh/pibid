migration 201312020808, :remove_duplicate_transactions do
  up do
    transactions = Transaction.all
    transactions.each do |tx|
      duplicates = transactions.select do |rhs|
        rhs.id != tx.id &&
        rhs.note == tx.note &&
        rhs.amount == tx.amount &&
        rhs.currency == tx.currency &&
        rhs.occured_on == tx.occured_on
      end

      if duplicates.length
        puts "Transaction #{tx.id} has #{duplicates.length} duplicates: #{duplicates.map(&:id).join(', ')}"
      end
    end
  end

  down do
  end
end