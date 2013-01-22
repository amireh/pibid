object @category
attributes :name
child(@category.user => :user) {
  attributes :id
}