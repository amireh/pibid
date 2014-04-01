ability do |user|
  # user ||= User.new

  return false if !user

  can :access, User do |u|
    u.id == user.id
  end

  can :access, [ Category, PaymentMethod, Account, Notice, Journal ] do |r|
    r.user.id == user.id
  end

  can :access, Transaction do |tx|
    can? :access, tx.account
  end
  can :access, Attachment do |attachment|
    can? :access, attachment.transaction
  end

end

user do current_user end