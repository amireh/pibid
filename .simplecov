SimpleCov.start do
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Helpers", "app/helpers"

  add_filter "app/views"
  add_filter "config"
  add_filter "lib/tasks"
  add_filter "spec/datamapper/is_lockable_spec.rb"
  add_filter "spec/datamapper/is_locatable_spec.rb"
end