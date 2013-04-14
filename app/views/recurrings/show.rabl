object @transaction => ''
extends "transactions/show"

attributes :flow_type, :frequency, :active, :next_billing_date

node(:recurs_on) do |tx|
  recurrence = tx.recurs_on

  if recurrence && recurrence.year < 1
    recurrence = DateTime.new(Time.now.year, recurrence.month, recurrence.day)
  end

  recurrence
end