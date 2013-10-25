extends "recurrings/_show"

node(:occurences) do |t|
  t.schedule.all_occurrences
end