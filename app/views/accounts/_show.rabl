object @account

attributes :id, :label, :currency

node(:balance) { |a| a.balance.to_f.round(2) }

node(:media) do |a|
  {
    url:    a.url,
    transactions: {
      url:  a.url(true) + '/transactions'
    }
  }
end
