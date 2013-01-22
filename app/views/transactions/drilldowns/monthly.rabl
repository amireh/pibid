@drilled_transies.each_pair do |day, transies|
  child :"#{day}" do
    node :transactions do
      transies.map { |tx|
        partial("transactions/show", object: tx )
      }
    end
  end
end