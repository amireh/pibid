require 'lib/datamapper/is/journallable'

class Transaction
  include DataMapper::Resource

  default_scope(:default).update(:order => [ :occured_on.desc ])

  property :id,           Serial

  # The raw amount of the transaction.
  property :amount,       Decimal, scale: 2, required: true, message: 'Transaction amount is missing.'

  # The transaction currency is the currency used when the transaction
  # was made, and if it differs from the account currency, the proper
  # exchange rate conversion will be made in the account balance and NOT
  # the transaction itself.
  property :currency,       String, length: 3, default: lambda { |r,*_| r.account.currency }
  property :currency_rate,  Decimal, scale: 2, default: lambda { |r,*_| Currency[r.account.currency].rate }

  property :note, Text, default: "", lazy: false

  # Transactions can be either deposits, withdrawals, or recurrings
  property :type, Discriminator

  property :occured_on, DateTime, default: lambda { |*_|
    now = DateTime.now.utc;
    DateTime.new(now.year, now.month, now.day).utc
  }
  property :created_at, DateTime, default: lambda { |*_| DateTime.now.utc }

  belongs_to :account, required: true
  belongs_to :payment_method, required: false, default: lambda { |tx,*_| tx.account.user.payment_method }
  belongs_to :recurring, required: false

  has n, :categories, :through => Resource, :constraint => :skip

  is :journallable

  before :destroy do
    CategoryTransaction.all({ transaction_id: self.id }).destroy
  end

  def url
    "#{self.account.url(true)}/transactions/#{id}"
  end

  validates_with_method :currency, :valid_currency?

  [ 'withdrawal', 'deposit', 'recurring' ].each { |t|
    define_method("#{t}?") { self.type.to_s == t.capitalize }
    alias_method :"is_#{t}?", :"#{t}?"
  }

  def valid_currency?
    unless Currency.valid?(self.currency)
      return [ false, "Unrecognized currency." ]
    end

    true
  end

  def +(y)
    y
  end

  def enforce_occurrence_resolution(dt = self.occured_on)
    dt ||= Time.now.utc
    Time.utc(dt.year, dt.month, dt.day, 0, 0, 0)
  end

  def occured_on=(dt)
    super(enforce_occurrence_resolution(dt))
  end

  after :create do
    add_to_account(to_account_currency)
    self.account.save
  end

  before :save do
    if !self.amount || self.amount.to_f <= 0
      self.errors.add :amount, 'Transaction amount must be a positive number.'
      throw :halt
    end

    # if attribute_dirty?(:occured_on)
    #   self.occured_on = self.enforce_occurrence_resolution
    # end
  end

  # adjust the account balance if our amount or currency are being updated
  before :update do
    needs_adjustment = attribute_dirty?(:amount) || attribute_dirty?(:currency)

    if needs_adjustment

      # deduction:
      # the deductible amount should be what the amount and currency
      # where prior to the update *if* they were updated, technically
      # we have 4 permutations here

      dd_currency = case attribute_dirty?(:currency)
      when true;  original_attributes[Transaction.currency] # currency is dirty, get original
      when false; self[:currency]
      end

      dd_amount = case attribute_dirty?(:amount)
      when true;  original_attributes[Transaction.amount] # amount is dirty, get original
      when false; self[:amount]
      end

      deductible_amount = to_account_currency(dd_amount, dd_currency)
      deduct(deductible_amount)

      # update to the latest currency rate if currency has changed
      if attribute_dirty?(:currency)
        self.currency_rate = Currency[self[:currency]].rate
      end

      # addition:
      # nothing special to do here since the new amount and currency
      # are set already, see #to_account_currency
      added_amount = to_account_currency
      add_to_account(added_amount)

      # note the bang (!) version; we MUST bypass all hooks here
      # since otherwise there'd be a chicken-and-egg paradox!
      #
      # (account is dirty and can't be updated because the tx itself
      #  is dirty, which needs the account to be updated, and clean, to update)
      self.account.save!
    end

  end

  before :destroy do
    deduct(to_account_currency)
    self.account.save!
  end

  def deduct(amt)
  end

  def add_to_account(amt)
  end

  protected

  def to_account_currency(amount = self[:amount], mine = self[:currency], my_rate = self[:currency_rate])
    Currency[self.account[:currency]].from(Currency[mine], amount)
  end
end