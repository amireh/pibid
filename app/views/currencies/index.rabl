node :currencies do
  Currency.all.map { |c| partial "currencies/_show", object: c }
end
