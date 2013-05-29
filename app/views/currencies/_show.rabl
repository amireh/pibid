object @currency => ""

attributes :name, :symbol

node(:rate) do |c| (1 / c.rate.to_f).round(2) end