object @category

extends "categories/_show"

child(@category.user => :user) {
  node(:id) { |r| r.id }
}