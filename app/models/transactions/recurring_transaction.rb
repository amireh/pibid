# require 'app/models/transaction'

class Transaction; end
class Recurring < Transaction
  belongs_to :account, required: true

  attr_accessor :recurs_on_month, :recurs_on_day

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

    unless [ :yearly, :monthly, :daily ].include?( (self.frequency||'').to_sym)
      errors.add :frequency, "Frequency must be one of [ :yearly, :monthly, :daily ]"
    end

    unless [ :negative, :positive ].include?( (self.flow_type||'').to_sym)
      return "Flow type must be either :negative or :positive"
    end

    self.recurs_on = build_recurrence_date(self.frequency, recurs_on_month, recurs_on_day)
  end
  # validates_presence_of :note, message: 'Must provide a name for this bill'

  def build_recurrence_date(frequency, month, day)
    recurs_on, this_year = nil, Time.now.year

    month ||= 0
    day   ||= 0

    if self.recurs_on then
      month ||= self.recurs_on.month
      day   ||= self.recurs_on.day
    end

    month, day = month.to_i, day.to_i

    if frequency == :yearly && (month < 1 || month > 12)
      errors.add :recurs_on_month,  "Bad recurrence month [#{month}]; must be between 1 and 12"
      throw :halt
    end

    if frequency != :daily && (day < 1 || day > 32)
      errors.add :recurs_on_day,    "Bad recurrence day [#{day}]; must be between 1 and 32"
      throw :halt
    end

    case frequency
    when :monthly
      # only the day is used in this case
      begin
        recurs_on = DateTime.new(this_year, 1, day.to_i)
      rescue
        errors.add :recurs_on, "Bad recurrence day: [#{day}]"
        throw :halt
      end

    when :yearly
      # the day and month are used in this case
      begin
        recurs_on = DateTime.new(this_year, month.to_i, day.to_i)
      rescue
        errors.add :recurs_on, "Bad recurrence day or month [#{day}, #{month}]"
        throw :halt
      end
    else
      recurs_on = DateTime.now
    end

    recurs_on
  end

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
      payment_method: self.payment_method,
      categories: self.categories
    })

    unless t.valid? && t.saved?
      return false
    end

    # stamp the commit
    self.update({ last_commit: now })

    t
  end

  private

  def zero_out(time)
    Time.new(time.year, time.month, time.day)
  end
end