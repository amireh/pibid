object @transaction => ''

attributes :id, :note, :payment_method_id#, :occured_on

node(:type) { |tx| tx.type.to_s.downcase }
node(:amount) { |tx| tx.amount.to_f.round(2) }
node(:currency) { |tx| tx.currency }
node(:occured_on) { |tx| (tx.occured_on || DateTime.now).to_time.to_i + 3600 }
node(:categories) { |tx|
  tx.categories.map { |c| c.id }
}

# node(:categories) { |tx|
#   tx.categories.map { |c| c.id }
# }

# child(:payment_method => :payment_method) { |pm|
#   attributes :id
# }

# node(:payment_method) do |tx|
#   partial "payment_methods/show", object: tx.payment_method
# end

# node(:media) { |tx|
#   {
#     url: tx.url,
#     actions: {
#       edit: tx.url + '/edit'
#     }
#   }
# }
