object @tx => ''

attributes :id

node(:type) { |tx| tx.type.to_s[0].downcase }
node(:amount) { |tx| tx.amount.to_f.round(2) }
node(:currency) { |tx| tx.currency }
node(:categories) { |tx| tx.categories.map { |c| c.name } }
