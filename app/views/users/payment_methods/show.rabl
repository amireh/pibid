object @pm => :payment_method

attributes :name, :color, :default
child(@pm.user) {
  attributes :id
}