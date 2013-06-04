object @user => ""

attributes :name, :email, :gravatar_email, :email_verified

node(:id) { |r| r.id }
node(:links) do |u|
  u.links.map { |u| u.provider }
end

child :account do |a|
  node(:id) { |a| a.id }
end

node(:media) do |u|
  {
    url:              u.url,
    accounts:         u.url(true) + '/accounts',
    categories:       u.url(true) + '/categories',
    payment_methods:  u.url(true) + '/payment_methods',
    journal:          u.url(true) + '/journal',
    journals:         u.url(true) + '/journals',
    notices: {
      email: u.url(true) + '/notices/email',
      password: u.url(true) + '/notices/password'
    },
    stats:            u.url(true) + '/stats'
  }
end

# node(:payment_methods) do |u|
#   u.payment_methods.map { |pm| partial "payment_methods/show", object: pm }
# end

# node(:currencies) do |u|
#   Currency.all.map { |c| partial "currencies/_show", object: c }
# end

# node(:categories) do |u|
#   u.categories.map { |c| partial "categories/_show", object: c }
# end

node(:preferences) do |s|
  s.preferences
end
