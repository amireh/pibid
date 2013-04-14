node :transactions do
  @transies.map { |tx|
    partial("recurrings/show", object: tx )
  }
end