object @transaction => ''
extends "transactions/show"

attributes :flow_type,
  :frequency,
  :next_billing_date

node(:every) { |tx| tx.every }
node(:weekly_days) { |tx| tx.weekly_days }
node(:monthly_days) { |tx| tx.monthly_days }
node(:yearly_day) { |tx| tx.yearly_day }
node(:yearly_months) { |tx| tx.yearly_months }
node(:active) { |tx| tx.active? }
node(:recurrence) { |tx| tx.schedule.to_s }

# node(:recurs_on) do |tx|
#   tx.recurs_on.strftime("%m/%d/%Y")
# end