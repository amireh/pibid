# require 'app/models/transaction'

class Transaction; end
class Recurring < Transaction
  belongs_to :account, required: true
  has n, :transactions, :constraint => :set_nil

  Frequencies = [ :daily, :weekly, :monthly, :yearly  ]
  WeeklyDays = [ :sunday, :monday, :tuesday, :wednesday, :thursday, :friday, :saturday ]
  # attr_accessor :recurs_on_month, :recurs_on_day

  property :flow_type,  Enum[ :positive, :negative ],      default: :positive
  property :frequency,  Enum[ :daily, :monthly, :yearly, :weekly ]
  # property :recurs_on,  DateTime, default: lambda { |*_| DateTime.now.utc }
  property :last_commit, DateTime, allow_nil: true
  property :active,     Boolean, default: true

  property :every, Integer, default: 1

  property :weekly_days, CommaSeparatedList
  property :monthly_days, CommaSeparatedList

  property :yearly_months, CommaSeparatedList
  property :yearly_day, Integer

  validates_presence_of :every
  validates_presence_of :frequency
  validates_presence_of :weekly_days, :if => lambda { |t| t.frequency == :weekly }
  validates_presence_of :monthly_days, :if => lambda { |t| t.frequency == :monthly }
  validates_presence_of :yearly_months, :if => lambda { |t| t.frequency == :yearly }
  validates_presence_of :yearly_day, :if => lambda { |t| t.frequency == :yearly }

  before :save do
    self.weekly_days = [ self.weekly_days ] unless self.weekly_days.is_a?(Array)
    self.monthly_days = [ self.monthly_days ] unless self.monthly_days.is_a?(Array)
    self.yearly_months = [ self.yearly_months ] unless self.yearly_months.is_a?(Array)
    self.every = 1 if self.every.to_i < 1

    [ :weekly_days, :monthly_days, :yearly_months ].each do |arrkey|
      self[arrkey].reject! { |v| !v }
    end

    self.weekly_days = self.weekly_days.map(&:to_sym)

    if !self.note || self.note.to_s.empty?
      self.errors.add :note,
        self.flow_type == :negative ?
        "Must provide a name for this bill" :
        "Must provide a name for this income flow"

      throw :halt
    end

    unless Frequencies.include?( (self.frequency||'').to_sym)
      errors.add :frequency, "Frequency must be one of [ :yearly, :monthly, :daily ]"
      throw :halt
    end

    unless [ :negative, :positive ].include?( (self.flow_type||'').to_sym)
      errors.add :flow_type, "Flow type must be either :negative or :positive"
      throw :halt
    end

    case frequency
    when :yearly
      if yearly_day > 31 || yearly_day < -1
        errors.add :yearly_day, 'Yearly day must be between -1 and 31'
        throw :halt
      end
    when :monthly
      monthly_days.each do |day|
        day = day.to_i

        if day < -1 || day > 31
          errors.add :monthly_days, 'Monthly days must be between -1 and 31'
          throw :halt
        end
      end
    when :weekly
      weekly_days.each do |day|
        day = (day||'').to_sym

        unless WeeklyDays.include?(day)
          errors.add :weekly_days, "Weekly days must be one (or more) of #{WeeklyDays.join(', ')}"
          throw :halt
        end
      end
    end

    begin
      schedule
    rescue Exception => e
      errors.add :schedule, e.message
      throw :halt
    end
  end

  alias_method :_monthly_days=, :monthly_days=
  def monthly_days=(v)
    v ||= []
    v = [ v ] unless v.is_a?(Array)

    send :_monthly_days=, v
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

    s.add_recurrence_rule case frequency
    when :yearly
      IceCube::Rule.yearly(every).month_of_year(yearly_months || 1).day_of_month(yearly_day || 1)
    when :monthly
      IceCube::Rule.monthly(every).day_of_month(monthly_days || [])
    when :weekly
      IceCube::Rule.weekly(every).day(weekly_days || [])
    when :daily
      IceCube::Rule.daily(every)
    end

    s
  end

  def next_billing_date
    zero( schedule.next_occurrence(commit_anchor) )
  end

  def all_occurrences(_until = Time.now.utc)
    schedule.occurrences_between( commit_anchor+1, zero(_until) )
  end

  def zero(*args)
    if args.length == 1
      Time.utc(args[0].year, args[0].month, args[0].day)
    elsif args.length == 3
      Time.utc(*args)
    else
      Time.utc(args[0], args[1], args[2], 0, 0, 0)
    end
  end

  def due?
    next_billing_date <= zero(Time.now.utc)
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
    !!self.active
  end
end