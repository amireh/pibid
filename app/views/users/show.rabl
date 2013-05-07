object @user

attributes :id, :name, :email, :gravatar_email

node(:links) do |u|
  u.links.map { |u| u.provider }
end
node :account do |a|
  partial "accounts/show", object: @user.account
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
    },
    journal: {
      url: u.url(true) + '/journal'
    }
  }
end

node(:payment_methods) do |u|
  u.payment_methods.map { |pm| partial "payment_methods/show", object: pm }
end

node(:currencies) do |u|
  Currency.all.map { |c| partial "currencies/_show", object: c }
end

node(:categories) do |u|
  u.categories.map { |c| partial "categories/_show", object: c }
end

node(:preferences) do |s|
  s.preferences
end
