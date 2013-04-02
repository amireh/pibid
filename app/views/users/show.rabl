object @user

attributes :id, :name, :email

node :account do |a|
  partial "accounts/_show", object: @user.account
end

node(:media) do |u|
  {
    url:    u.url,
    accounts: {
      url:  u.url(true) + '/accounts'
    },
    categories: {
      url: u.url(true) + '/categories'
    },
    payment_methods: {
      url: u.url(true) + '/payment_methods'
    }
  }
end
