node :transactions do
  @transactions.map { |tx|
    partial("transactions/show", object: tx )
  }
end