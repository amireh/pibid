# require 'app/models/transaction'

class Transaction; end
class Recurring < Transaction
  belongs_to :account, required: true

  property :flow_type,  Enum[ :positive, :negative ],      default: :positive
  property :frequency,  Enum[ :daily, :monthly, :yearly ], default: :monthly
  property :recurs_on,  DateTime, default: lambda { |*_| DateTime.now }
  property :last_commit, DateTime, allow_nil: true
  property :active,     Boolean, default: true

  before :save do
    if !self.note || self.note.to_s.empty?
      self.errors.add :note,
        self.flow_type == :negative ?
        "Must provide a name for this bill" :
        "Must provide a name for this income flow"

      throw :halt
    end
  end
  # validates_presence_of :note, message: 'Must provide a name for this bill'

  def +(y)
    amount * (flow_type == :negative ? -1 : 1) + y
  end

  def next_billing_date()
    case frequency
    when :monthly
      if last_commit then
        t = nil
        Timetastic.fixate(last_commit) { t = 1.month.ahead }
        t
      else
        if recurs_on.day > Time.now.day
          return Time.new(Time.now.year, Time.now.month, recurs_on.day)
        else
          t = 1.month.ahead
          Time.new(t.year, t.month, recurs_on.day)
        end
      end
    when :yearly
      if last_commit then
        t = nil
          Timetastic.fixate(last_commit) { t = 1.year.ahead }
        t
      else
        if recurs_on.month < Time.now.month
          Time.new(Timetastic.next.year.year, recurs_on.month, recurs_on.day)
        else
          Time.new(Time.now.year, recurs_on.month, recurs_on.day)
        end
      end
    end
  end

  def applicable?(now = nil)
    now ||= Time.now
    now = now.to_time if now.respond_to?(:to_time) && !now.is_a?(Time)

    case frequency
    when :daily
      # recurs_on is ignored in this frequency
      return !last_commit ||              # never committed before
        Timetastic.days_between(last_commit.to_time, now) >= 1
    when :monthly
      # is it the day of the month the tx should be committed on?
      if recurs_on.day == now.day
        # committed already for this month?
        return !last_commit || zero_out(now) >= 1.month.ahead(zero_out last_commit.to_time)
      end
    when :yearly
      # is it the day and month of the year the tx should be committed on?
      if recurs_on.day == now.day && recurs_on.month == now.month
        # committed already for this year?
        return !last_commit || last_commit.year < now.year
      end
    end

    false
  end

  def commit(now = nil)
    return false unless self.active
    return false unless applicable?

    now ||= DateTime.now

    c = nil

    # get the transaction collection we'll be generating from/into
    if self.flow_type == :positive
      c = self.account.deposits
    else
      c = self.account.withdrawals
    end

    t = c.create({
      amount: self.amount,
      currency: self.currency,
      note: self.note,
      payment_method: self.payment_method
    })

    unless t.valid? && t.saved?
      return false
    end

    # stamp the commit
    self.update({ last_commit: now })
  end

  private

  def zero_out(time)
    Time.new(time.year, time.month, time.day)
  end
end