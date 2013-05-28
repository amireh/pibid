# object @categories

node(:categories) do |categories|
  @categories.map { |c| partial "categories/_show", object: c }
end