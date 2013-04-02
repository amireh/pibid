class Account
  include DataMapper::Resource

  property :id,           Serial
  property :label,        String, length: 48, default: "Personal"

  # The account balance is the sum of all of its transaction actual amounts
  # converted to the account currency
  property :balance,      Decimal, scale: 2, default: 0

  # The account currency does not affect its transactions' currencies,
  # it is only used to figure out the exchange rate whenever the balance
  # is updated
  property :currency,     String, default: "USD"

  property :created_at,   DateTime, default: lambda { |*_| DateTime.now }

  belongs_to :user, required: true
  has n, :transactions, :constraint => :destroy
  has n, :deposits,     :constraint => :destroy
  has n, :withdrawals, :constraint => :destroy
  has n, :recurrings,   :constraint => :destroy

  validates_with_method :currency, :method => :valid_currency?

  is :transactable

  def valid_currency?
    unless Currency.valid?(self.currency)
      return [ false, "Unrecognized currency." ]
    end

    true
  end

  def url(root = false)
    root ? "/accounts/#{id}" : "#{user.url}/accounts/#{id}"
  end
end