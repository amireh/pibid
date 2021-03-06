object @transaction => ''

attributes :note

node(:id) { |r| r.id }
node(:type) { |tx| tx.type.to_s.downcase }
node(:amount) { |tx| tx.amount.to_f.round(2) }
node(:currency) { |tx| tx.currency }
node(:occured_on) { |tx|
  tx.occured_on.to_i
}
node(:categories) { |tx|
  tx.categories.map { |c| c.id }
}
node(:payment_method_id) { |tx| tx.payment_method_id }
node(:recurring_id) { |tx| tx.recurring_id }

# node(:categories) { |tx|
#   tx.categories.map { |c| c.id }
# }

# child(:payment_method => :payment_method) { |pm|
#   attributes :id
# }

# node(:payment_method) do |tx|
#   partial "payment_methods/show", object: tx.payment_method
# end