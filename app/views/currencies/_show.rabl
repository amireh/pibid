object @currency => ""

attributes :name, :symbol

node(:rate) do |c| c.rate.to_f end