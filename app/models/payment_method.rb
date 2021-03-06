class PaymentMethod
  include DataMapper::Resource

  default_scope(:default).update(:order => [ :name.asc ])

  Colors = [ 'FFBB33', '99CC00', 'CC0000', '33B5E5', 'AA66CC', 'B147A3' ]

  belongs_to :user, required: true

  property :id, Serial
  property :name, String, length: 50, required: true,
    messages: {
      presence: 'Payment method requires a name!'
    }

  property :default, Boolean, default: false
  property :color, String, length: 6, default: lambda { |*| PaymentMethod.some_color }

  has n, :transactions, :constraint => :set_nil
  has n, :deposits,     :constraint => :set_nil
  has n, :withdrawals,  :constraint => :set_nil
  has n, :recurrings,   :constraint => :set_nil

  is :transactable
  is :journallable

  validates_uniqueness_of :name, :scope => :user_id,
    message: "You have already registered that payment method."

  validates_uniqueness_of :default, :scope => :user_id,
    message: 'You already have a default payment method!'

  # before :save do
  #   if attribute_dirty?(:default) && self.default == true && user.payment_method
  #     user.payment_method.update({ default: false })
  #   end

  #   true
  # end

  def colorize
    self.update({ color: some_color })
  end

  def self.some_color
    Colors[rand(Colors.size)]
  end
end