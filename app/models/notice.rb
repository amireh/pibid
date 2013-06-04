class Notice
  include DataMapper::Resource
  include Pibi::Helpers

  property    :id,          Serial
  property    :salt,        String, length: 255
  property    :data,        String, length: 255
  property    :created_at,  DateTime, default: lambda { |*_| DateTime.now }
  property    :accepted_at, DateTime
  property    :type,        String, length: 255
  property    :status,      Enum[ :pending, :expired, :accepted ], default: :pending
  property    :dispatched,  Boolean, default: false
  belongs_to  :user, required: true

  before :create do |ctx|
    self.salt = tiny_salt(4)#(self.user.email)
    true
  end

  def expired?
    status == :expired
  end

  def pending?
    status == :pending
  end

  def accepted?
    status == :accepted
  end

  def accept!
    update({ status: :accepted, accepted_at: DateTime.now })
    user.on_notice_accepted(self)
  end

  def expire!
    update({ status: :expired })
    user.on_notice_expired(self)
  end

  def url
    "/notices/#{self.salt}/accept"
  end
  alias_method :acceptance_url, :url

  # is :locatable, by: :salt
end