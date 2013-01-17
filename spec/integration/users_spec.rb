describe "Signing up for a new account" do
  before do
    User.destroy
  end

  def fill_form(in_q = {}, &cb)
    q = mockup_user_params.merge(in_q)

    rc = prc post '/users', q

    rc.should fail unless in_q.empty?

    cb.call(rc) if block_given?
  end

  it "Signing up with no name" do
    fill_form({ name: '' }) do |rc|
      rc.should fail('need your name')
    end
  end

  scenario "Signing up with no email" do
    fill_form({ email: '' }) do |rc|
      rc.should fail('need your email')
    end
  end

  scenario "Signing up with an invalid email" do
    fill_form({ email: 'this is no email' }) do |rc|
      rc.should fail('look like an email')
    end
  end

  scenario "Signing up with a taken email" do
    mockup_user

    fill_form({ email: mockup_user_params[:email] }) do |rc|
      rc.should fail('already registered')
    end
  end

  scenario "Signing up without a password" do
    fill_form({ password: '' }) do |rc|
      rc.should fail('must provide password')
    end
  end

  scenario "Signing up with mis-matched passwords" do
    fill_form({ password: 'barfoo123' }) do |rc|
      rc.should fail('must match')
    end
  end

  scenario "Signing up with a password too short" do
    fill_form({ password: 'bar', password_confirmation: 'bar' }) do |rc|
      rc.should fail('be at least characters long')
    end
  end

  scenario "Signing up with correct info" do
    fill_form do |rc|
      rc.should_not fail
    end
  end

end
