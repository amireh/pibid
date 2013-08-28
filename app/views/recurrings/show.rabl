object @transaction => ''
extends "transactions/show"

attributes :flow_type, :frequency, :next_billing_date

node(:active) do |tx|
  tx.active
end

node(:recurs_on) do |tx|
  tx.recurs_on.strftime("%m/%d/%Y")
end