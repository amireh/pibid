def sign_out
  delete '/sessions'
  authorize '', ''
end

def sign_in(u = @user)
  raise 'Must create a mockup user before signing in' unless u

  authorize u.email, Fixtures::UserFixture.password
end