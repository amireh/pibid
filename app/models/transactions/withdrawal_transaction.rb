# require 'app/models/transaction'

class Transaction; end
class Withdrawal < Transaction
  belongs_to :account, required: true

  def add_to_account(amt)
    account.balance -= amt
  end

  def deduct(amt)
    account.balance += amt
  end

  def +(y)
    to_account_currency * -1 + y
  end
end