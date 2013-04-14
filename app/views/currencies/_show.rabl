object @currency

attributes :name
node(:rate) do |c| c.rate.to_f end