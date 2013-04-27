class Currency
  include DataMapper::Resource

  property :id,     Serial
  property :name,   String, length: 3, unique: true
  property :rate,   Decimal, scale: 2, required: true
  property :symbol, String, length: 3, default: lambda { |c,*_| c.name }

  class << self
    def valid?(cur)
      Currency.all({ conditions: { name: cur }, fields: [ :id ] }).count == 1
    end

    def [](name)
      Currency.first({ name: name })
    end

    def all_names
      n = []; Currency.all.each { |c| n << c.name }; n
    end
  end

  # converts an amount from an original currency to this one
  # curr can be either a String or a Currency
  def from(curr, amt)
    c = curr.is_a?(String) ? Currency[curr] : curr
    (c.normalize(amt) * self.rate).round(2)
  end

  # converts an amount from this currency to another one
  # curr can be a String or a Currency
  def to(curr, amt)
    c = curr.is_a?(String) ? Currency[curr] : curr
    c.from(self, amt)
  end

  # converts the given amount to USD based on this currency rate
  def normalize(amt)
    amt / self.rate
  end
end