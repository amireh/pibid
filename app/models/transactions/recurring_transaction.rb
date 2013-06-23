# require 'app/models/transaction'

class Transaction; end
class Recurring < Transaction
  belongs_to :account, required: true
  has n, :transactions, :constraint => :set_nil

  FrequencyIntervals = {
    daily:    86400,
    weekly:   604800,
    monthly:  2.63e+6,
    yearly:   3.156e+7
  }

  FrequencyMethods = {
    daily:    :days,
    monthly:  :months,
    yearly:   :years
  }

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
  # validates_presence_of :note, message: 'Must provide a name for this bill'

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
    else
      recurs_on = DateTime.new(this_year, 1, day)
    end

    recurs_on
  end

  def +(y)
    amount * (flow_type == :negative ? -1 : 1) + y
  end

  # The anchor on which the next billing date should be based.
  #
  # If the recurring has been committed at least once (last_commit is valid)
  # then the anchor is set to the last commit date, otherwise the anchor
  # is based on the frequency type:
  #
  # * daily: the anchor is set to 1 day ahead of the creation time
  # * monthly: the anchor is set to 1 month ahead of the creation time, taking
  #   into account the day of recurrence
  # * yearly: the anchor is set to 1 year ahead of the creation time, taking
  #   into account both the day and month of recurrence
  #
  # @return Time object
  def commit_anchor(lc = last_commit)
    if lc then
      # puts "Last commit @ #{lc.strftime('%D')}"
      return Timetastic.zero lc.to_time
    end

    anchor = case frequency
    when :daily
      Timetastic.zero created_at.to_time
    when :monthly
      Timetastic.zero Time.new(created_at.year, created_at.month, recurs_on.day)
    when :yearly
      Timetastic.zero Time.new(created_at.year, recurs_on.month, recurs_on.day)
    end
  end

  def next_billing_date(anchor = nil, relative_to = nil)
    ca = commit_anchor

    if anchor && anchor.is_a?(Hash)
      options     = anchor
      anchor      = options[:anchor]
      relative_to = options[:relative_to]
    end

    anchor      = Timetastic.zero(anchor || ca)
    relative_to = Timetastic.zero(relative_to || Time.now)

    offset = relative_to.to_i - anchor.to_i
    interval = FrequencyIntervals[frequency]

    # puts "Interval = #{interval}, offset = #{offset}"

    if offset < 0 && offset.abs < interval
      # puts "\tIt's this period, fixating to anchor"
      return anchor
    end

    Timetastic.zero(1.send(FrequencyMethods[self.frequency]).ahead(anchor))
  end

  def all_occurences(_until = Time.now)
    _until = Timetastic.zero _until

    occurences = []
    anchor = next_billing_date({
      relative_to: Timetastic.zero(last_commit || created_at)
    })

    while anchor.to_i < _until.to_i
      occurences << anchor
      anchor = next_billing_date({ anchor: anchor, relative_to: anchor })
    end

    occurences
  end

  def due?(now = nil)
    now ||= Time.now
    now = now.to_time if now.respond_to?(:to_time) && !now.is_a?(Time)
    now = Timetastic.zero(now)
    nbd = next_billing_date({ relative_to: now })

    # puts '' <<
    #   "Due on: #{nbd.strftime('%D')}, now is: #{now.strftime('%D')}" <<
    #   ", last commit was at: #{last_commit && last_commit.strftime('%D')}"

    nbd.to_i <= now.to_i
  end

  alias_method :applicable?, :due?

  def commit(occurence = next_billing_date)
    occurence = Timetastic.zero(occurence)

    return false unless self.active
    return false if !due?(occurence)

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
      occured_on: occurence,
      categories: self.categories,
      recurring: self
    })

    unless t.valid? && t.saved?
      return false
    end

    # stamp the commit
    self.update!({ last_commit: occurence })

    t
  end

  def committed_before?
    !!last_commit
  end
end