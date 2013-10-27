object @transaction => ''
extends "recurrings/_show"

node(:occurrences) { |tx|
  tx.schedule.occurrences(Time.now.end_of_year)
}