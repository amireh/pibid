code :transactions do
  @transies.map { |tx| partial("transactions/show", object: tx ) }
end