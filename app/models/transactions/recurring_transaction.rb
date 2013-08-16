# require 'app/models/transaction'

class Transaction; end
class Recurring < Transaction
  belongs_to :account, required: true
  has n, :transactions, :constraint => :set_nil

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

    if attribute_dirty?(:recurs_on) || !recurs_on
      self.recurs_on = build_recurrence_date(self.frequency, recurs_on_month, recurs_on_day)
    end
  end

  def build_recurrence_date(frequency, month, day)
    recurs_on = nil
    this_year = Time.now.year

    frequency = frequency.to_sym
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

    if frequency != :daily && (day < 1 || day > 31)
      errors.add :recurs_on_day,    "Bad recurrence day [#{day}]; must be between 1 and 31"
      throw :halt
    end

    case frequency
    when :monthly
      # only the day is used in this case
      begin
        recurs_on = DateTime.new(this_year, 1, day)
      rescue
        errors.add :recurs_on, "Bad recurrence day: [#{day}]"
        throw :halt
      end

    when :yearly
      # the day and month are used in this case
      begin
        recurs_on = DateTime.new(this_year, month, day)
      rescue
        errors.add :recurs_on, "Bad recurrence day or month [#{day}, #{month}]"
        throw :halt
      end
    when :daily
      recurs_on = DateTime.new(this_year, 1, 1)
    end

    recurs_on
  end

  def +(y)
    amount * (flow_type == :negative ? -1 : 1) + y
  end

  # The time anchor on which the next commit should be based on.
  #
  # If the recurring has been committed at least once (last_commit is valid)
  # then the anchor is set to the last commit date, otherwise the anchor
  # is the date of the recurring's creation.
  #
  # @return Time object
  def commit_anchor
    zero( (last_commit || created_at).to_time )
  end

  def schedule
    s = IceCube::Schedule.new( commit_anchor )

    r = case frequency
    when :yearly
      IceCube::Rule.yearly.month_of_year(recurs_on.month).day_of_month(recurs_on.day)
    when :monthly
      IceCube::Rule.monthly.day_of_month(recurs_on.day)
    when :daily
      IceCube::Rule.daily
    end

    s.add_recurrence_rule(r)
    s
  end

  def next_billing_date
    zero( schedule.next_occurrence(commit_anchor) )
  end

  def all_occurrences(_until = Time.now)
    schedule.occurrences_between( commit_anchor+1, zero(_until) )
  end

  def zero(*args)
    if args.length == 1
      Time.new(args[0].year, args[0].month, args[0].day)
    elsif args.length == 3
      Time.new(*args)
    else
      Time.new(args[0], args[1], args[2], 0, 0, 0)
    end
  end

  def due?
    next_billing_date <= zero(Time.now)
  end

  def commit
    return false if !active? || !due?

    occurrence = next_billing_date

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
      occured_on: occurrence,
      categories: self.categories,
      recurring: self
    })

    unless t.valid? && t.saved?
      return false
    end

    # stamp the commit
    self.update!({ last_commit: occurrence })

    t
  end

  def committed_before?
    !!last_commit
  end

  def active?
    self.active
  end
end