object @category

extends "categories/_show"

child(@category.user => :user) {
  attributes :id
}