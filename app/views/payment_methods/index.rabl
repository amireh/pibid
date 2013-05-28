node(:payment_methods) do |payment_methods|
  @payment_methods.map { |pm| partial "payment_methods/show", object: pm }
end