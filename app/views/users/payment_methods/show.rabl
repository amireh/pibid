object @pm

attributes :name, :color
child(@pm.user) {
  attributes :id
}