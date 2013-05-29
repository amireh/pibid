object @account => ""

attributes :label, :currency

node(:id) { |r| r.id }
node(:balance) { |a| a.balance.to_f.round(2) }
node(:media) do |a|
  {
    url:    a.url,
    transactions: {
      url:  a.url(true) + '/transactions',
      drilldown: a.url(true) + '/transactions/drilldown'
    },
    recurrings: a.url(true) + '/recurrings'
  }
end
