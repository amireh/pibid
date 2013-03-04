collection @categories, :object_root => false

attributes :id

node(:id) { |tx| tx.id }
node(:name) { |tx| tx.name }

