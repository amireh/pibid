require 'resolv'

class User
  include DataMapper::Resource
  include Pibi::Helpers

  def self.default_categories=(names = [])
    @@default_categories = names
  end

  def self.default_categories
    @@default_categories
  end

  MinPasswordLength = 7

  property :id, Serial

  property :name,     String, length: 255, required: true, message: 'We need your name.'
  property :provider, String, length: 255, required: true
  property :uid,      String, length: 255, default: lambda { |*u| UUID.generate }
  property :password, String, length: 64,  required: true, message: 'You must provide a password!'

  property :email,    String, length: 255, required: true,
    format: :email_address,
    messages: {
      presence:   'We need your email address.',
      format:     "Doesn't look like an email address to me..."
    }

  property :email_verified, Boolean, default: false
  property :gravatar_email, String, length: 255, format: :email_address, default: lambda { |r,_| r.email }
  # property :settings,       Text, default: "{}"
  property :oauth_token,    Text
  property :oauth_secret,   Text
  property :extra,          Text
  property :auto_password,  Boolean, default: false
  property :created_at,     DateTime, default: lambda { |*_| DateTime.now }
  # property :is_admin,       Boolean, default: false
  # property :is_public,      Boolean, default: false

  belongs_to :link, self, :child_key => [ :link_id ], :required => false
  has n, :links, self, :child_key => [ :link_id ], :constraint => :destroy

  has n, :notices, :constraint => :destroy
  has n, :accounts, :constraint => :destroy
  has n, :categories, :constraint => :destroy
  has n, :payment_methods, :constraint => :destroy
  has n, :journals, :constraint => :destroy

  attr_accessor :password_confirmation

  validates_confirmation_of :password,
    message: 'Passwords must match.'
  validates_length_of       :password, :min => MinPasswordLength,
    message: "Password is too short, it must be at least #{MinPasswordLength} characters long."

  validates_uniqueness_of :email, :scope => :provider,
    message: "There's already an account registered to this email address."

  # is :locatable
  is :preferencable
  is :journallable

  # --------- -------
  # DISABLED: LOCKING
  # --
  # is :lockable
  #
  # before :valid? do |*_|
  #   !is_locked
  # end
  # -----------------

  # invalidate email verification status if email is updated
  before :update do
    if attribute_dirty?(:email)
      self.email_verified = false
    end
  end

  before :save do
    if attribute_dirty?(:password)
      if password != password_confirmation
        errors.add :password, "Passwords do not match."
        throw :halt
      end

      attribute_set(:password, User.encrypt(password))
      attribute_set(:password_confirmation, User.encrypt(password_confirmation))
    end
  end

  def account
    self.accounts.first
  end

  def create_default_pm()
    self.payment_methods.first_or_create({ name: "Cash", default: true })
  end

  # generate an email verification notice if necessary
  [ :create, :update ].each do |advice|
    after advice do
      unless email_verified? or awaiting_email_verification?
        verify_email
      end
    end
  end

  before :destroy do
    # self.link && self.link.destroy
    # self.links.destroy
    self.notices.destroy!
  end

  after :create do
    self.accounts.create

    self.payment_methods.create({ name: "Cash", default: true })
    self.payment_methods.create({ name: "Cheque" })
    self.payment_methods.create({ name: "Credit Card" })

    self.class.default_categories.each do |cname|
      self.categories.create({ name: cname, icon: cname.sanitize })
    end
  end

  class << self
    # TODO: this needs to be changed
    def encrypt(pw)
      Digest::SHA1.hexdigest(pw || "")
    end
  end

  def payment_method
    payment_methods.first({ default: true })
  end

  def linked_to?(provider)
    if provider.is_a?(User)
      provider = provider.provider
    end

    links.first({ provider: provider.to_s }) ||
    (self.link && self.link.provider == provider)
  end

  # will link this user resource to the given 'master' user
  # it will also link any previously linked users to this account
  # to the master (there should be only one master account)
  def link_to(master, soft = false)
    return true if master == self

    master.links << self

    self.link = master
    self.links.each { |linked_user|
      linked_user.link_to(master, false)
    }
    self.links = []

    rc = self.save

    unless soft
      rc = master.save && rc
    end

    rc
  end

  def detach_from_master()
    self.link = nil
    self.save
  end

  # ----
  # Notifications
  # ----
  def notice_count
    notices.all({status: :pending }).count
  end

  def pending_notices(q = {})
    notices.all(q.merge({ status: :pending }))
  end

  def on_notice_accepted(notice)
    case notice.type
    when 'email'
      update({ email_verified: true })
    when 'password'
      update({ auto_password: false })
    end

    # don't destroy it for history sake
  end

  def on_notice_expired(notice)
    # don't destroy for now
    # notice.destroy
  end

  # Replaces the current password with an auto generated one and
  # creates a notice of type 'password' to be dispatched to the user
  #
  # Note: since the password is encrypted prior to saving, the raw version
  # is kept in the notice's @data field for use when sending the notice email
  def generate_temporary_password

    pw = tiny_salt
    # puts ">> User: generating a temporary password '#{pw}' <<"
    # update!({ password: User.encrypt(pw), auto_password: true })

    # expire all current/old temp passwords that weren't used
    pending_notices.all({ type: 'password' }).each { |n| n.expire! }

    notices.create({ type: 'password', data: pw })
  end

  # ----
  # Email verification
  #
  # The deal here is that a Notice is sent to the user's registered email
  # address containing a link which, when visited, will verify the address
  # ----
  def email_verified? # an alias to the field
    email_verified
  end

  # creates an email verification notice
  def verify_email
    # remove any notice(s) for past email addresses
    pending_notices.all({ :data.not => self.email, type: 'email' }).destroy

    unless n = pending_notices.first_or_create({ data: self.email, type: 'email' })
      errors.add :notices, n.errors
      return false
    end

    n
  end

  # has an email notice been dispatched and is still pending?
  def awaiting_email_verification?
    return false if email_verified?

    pending_notices({ type: 'email', dispatched: true }).any?
  end

  def top_spending_categories(q = {})
    top_categories(q.merge({ type: Withdrawal }))
  end
  def top_earning_categories(q = {})
    top_categories(q.merge({ type: Deposit }))
  end

  def top_categories(q = {})
    categories.sort { |a,b| a.transactions(q).count <=> b.transactions(q).count }.reverse
  end

  def url(root = nil)
    "/users/#{id}"
  end

  private

  # Validates an email domain using Ruby's DNS resolver.
  # Thanks to:
  # => http://www.buildingwebapps.com/articles/79182-validating-email-addresses-with-ruby
  # def validate_email_domain(email)
  #   domain = email.match(/\@(.+)/)[1]
  #   Resolv::DNS.open do |dns|
  #     @mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
  #   end
  #   @mx.size > 0 ? true : false
  # end

  # Validates whether the given string is a valid and genuine email address
  # def validate_email!
  #   unless email.nil? || email.empty?
  #     unless email.is_email?
  #       errors.add(:email, "Your email address does not appear to be valid.")
  #       throw :halt
  #     else
  #       unless validate_email_domain(email)
  #         errors.add(:email, "Your email domain name appears to be incorrect.")
  #         throw :halt
  #       end
  #     end
  #   end
  # end

end