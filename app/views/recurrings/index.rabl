node :transactions do
  @transies.map { |tx|
    partial("recurrings/_show", object: tx )
  }
end