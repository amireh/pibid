object @payment_method => ""

attributes :name, :color, :default

node(:id) { |r| r.id }
# child(:user) {
#   attributes :id
# }