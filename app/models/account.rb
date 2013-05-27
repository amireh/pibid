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

  validates_presence_of   :label, message: 'You must provide a name for the account!'
  validates_uniqueness_of :label, :scope => [ :user_id ],
    message: "You already have such an account."

  is :transactable
  is :journallable

  def valid_currency?
    unless Currency.valid?(self.currency)
      return [ false, "Unrecognized currency." ]
    end

    true
  end

  def url(root = false)
    root ? "/accounts/#{id}" : "#{user.url}/accounts/#{id}"
  end

  before :update do
    if attribute_dirty?(:currency)
      old_iso = original_attributes[Account.currency]
      cur_iso = self[:currency]

      self.balance = Currency[cur_iso].from(old_iso, self[:balance])
    end
  end
end