module Fixtures

  class << self
    def [](type)
      @@fixtures ||= {}
      @@fixtures[type.to_sym].new
    end

    def register
      @@fixtures ||= {}
      # @@fixtures[type.to_sym] = klass
      constants.reject { |k| k == :Fixture }.each do |kname|
        @@fixtures[kname.to_s.gsub(/Fixture/, '').downcase.to_sym] = eval "Fixtures::#{kname.to_s}"
      end
    end

    def available_fixtures
      @@fixtures ||= {}
      @@fixtures.collect { |type,_| type }
    end

    def teardown
      User.destroy.should == true
      [
        User,
        Account,
        Transaction,
        Category,
        PaymentMethod,
        Notice
      ].each do |r|
        unless r.count == 0
          raise "[ERROR] Cleanup: expected #{r} to contain 0 resources, but got #{r.count}"
        end
      end
    end

    include Pibi::Helpers

    def gen_id
      @@id ||= 0
      @@id += 1
    end
  end

  class Fixture
    attr_reader :params

    def cleanup
      raise "Must be implemented by child."
    end

    def build(params = {})
      raise "Must be implemented by child."
    end

    def salt
      Fixtures.salt
    end
    def tiny_salt
      Fixtures.tiny_salt
    end

    def accept(params, p = @params)
      params.each_pair { |k,v|
        next unless p.has_key?(k)

        if v.is_a?(Hash)
          accept(v, p)
          next
        end

        p[k] = v
      }
      p
    end
  end

  class UserFixture < Fixture
    def self.password
      'verysalty123'
    end

    def build(params, cleanup = false)
      Fixtures.teardown if cleanup

      pw = self.class.password

      @params = accept(params, {
        name:     'Mysterious Mocker',
        email:    'spec@pagehub.org',
        provider: 'pibi',
        password:               pw,
        password_confirmation:  pw
      })

      u,a = nil,nil

      if u = User.create(@params)
        if a = u.accounts.first
        end
      end

      [ u, a ]
    end
  end # UserFixture

  class AccountFixture < Fixture
    def build(user, params)
      @params = accept(params, {
        label:  "Some Account #{Fixtures.gen_id}",
        currency: "USD",
        balance: 0.0,
        user:   user
      })

      user.accounts.create(@params)
    end
  end # UserFixture


  class DepositFixture < Fixture
    def build(account, params = {})
      raise ":deposit fixture requires a valid @account" unless account

      @params = accept(params, {
        amount:     rand(50) + 1,
        note:       'foobar',
        occured_on: nil,
        currency:   account.currency,
        categories: [],
        payment_method: nil
      })

      categories = @params.delete :categories

      tx = account.deposits.create(@params)

      if categories.any?
        categories.each do |cid|
          if c = account.user.categories.get(cid)
            tx.categories << c
          end
        end

        tx.save
      end

      tx
    end
  end # DepositFixture

  class RecurringFixture < Fixture
    def build(account, params = {})
      raise ":recurring fixture requires a valid @account" unless account

      @params = accept(params, {
        note:       "Recurrie##{tiny_salt}",
        amount:     rand(50) + 1,
        frequency: :daily,
        flow_type: :positive,
        recurs_on_month:  Time.now.month,
        recurs_on_day:    Time.now.day,
        currency:   account.currency,
        created_at: DateTime.now,
        categories: [],
        payment_method: nil
      })

      @params[:categories] = @params[:categories].map { |cid|
        account.user.categories.get(cid)
      }.reject(&:nil?)

      account.recurrings.create(@params)
    end
  end # DepositFixture

  class CategoryFixture < Fixture

    def build(user, params = {})
      raise ":category fixture requires a valid @user" unless user

      @params = accept(params, {
        name: "Mockup category #{Fixtures.tiny_salt}",
      })

      user.categories.create(@params)
    end
  end # DepositFixture


end # Fixtures

Fixtures.register
puts "Available fixtures: #{Fixtures.available_fixtures}"

# resource mock
def fixture(resource, o = {})
  case resource
  when :user
    # Fixtures[:user].build(o, true)
    # @u, @s, @f = *create_user(o, cleanup)
    @u, @a = *Fixtures[:user].build(o, true)
    valid! @u
    valid! @a
    @user, @account = @u, @a
    @u
  when :another_user
    # @u2, @s2, @f2 = create_user({ email: "more@mysterious" }, false)
    @u2, @a2 = *Fixtures[:user].build({
      email: "spec_shadow@pibibot.com"
    }.merge(o))
    @user2, @account2 = @u2, @a2
    @u2
  when :some_user
    Fixtures[:user].build({
      email: "spec#{Fixtures.gen_id}@pibibot.com"
    }.merge(o)).first
  when :account
    user = o[:user] || @user
    if !user
      fixture :user
      user = @u
    end

    Fixtures[:account].build(user, o)
  when :deposit
    @tx = Fixtures[:deposit].build(@account, o)
  when :recurring
    @rtx = Fixtures[:recurring].build(@account, o)
  when :category
    @c = Fixtures[:category].build(@user, o)
  end
end

def invalid!(r)
  r.saved?.should be_false
  r
end

def valid!(r)
  r.all_errors.should == []
  r.saved?.should be_true
  r
end

def fixture_wipeout
  Fixtures.teardown
end

def mockup_user_params
  @some_salt = Fixtures.tiny_salt
  @mockup_user_params = {
    name: 'Mysterious Mocker',
    email: 'very@mysterious.com',
    provider: 'pibi',
    password:               @some_salt,
    password_confirmation:  @some_salt
  }
end

def mockup_user(q = {})
  # User.destroy
  # @user     = @u = User.create(mockup_user_params.merge(q))
  # @account  = @a = @user.accounts.first

  # @user.saved?
  fixture(:user)
end
