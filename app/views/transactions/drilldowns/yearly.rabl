# @drilled_transies.each_pair do |month, transies|
#   child :"#{month}" do
#     node :transactions do
#       transies.map { |tx|
#         partial("transactions/show", object: tx )
#       }
#     end
#   end
# end
# @drilled_transies.each_pair do |month, transies|
# @transies.each do |month, transies|
  # child :"#{month}" do
    node :transactions do
      @transies.map { |tx|
        partial("transactions/show", object: tx )
      }
    # end
  # end
end