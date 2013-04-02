source :rubygems

gem 'sinatra', '=1.4.0',
  :git => 'https://github.com/sinatra/sinatra'
gem 'sinatra-contrib',
  :git => 'https://github.com/sinatra/sinatra-contrib',
  :require => [ 'sinatra/namespace', 'sinatra/config_file' ]
gem 'mysql'
gem 'json'
gem "dm-core", ">=1.2.0"
gem "dm-serializer", ">=1.2.0"
gem "dm-migrations", ">=1.2.0", :require => [
  'dm-migrations',
  'dm-migrations/migration_runner'
]
gem "dm-validations", ">=1.2.0"
gem "dm-constraints", ">=1.2.0"
gem "dm-types", ">=1.2.0"
gem "dm-mysql-adapter", ">=1.2.0"
gem 'multi_json'
gem 'addressable'
gem 'uuid'
# gem 'timetastic', '>= 0.1.5', :git => 'https://github.com/amireh/timetastic'
gem 'timetastic', '>= 0.1.5', :path => "/home/kandie/Workspace/Projects/timetastic"
gem "pony"
gem 'omniauth'
gem 'omniauth-facebook'
gem 'omniauth-github'
# gem 'omniauth-twitter', '0.0.9'
gem 'omniauth-google-oauth2'
gem 'rabl'
gem 'yajl-ruby'
gem 'sinatra-cross_origin', :require => 'sinatra/cross_origin'

group :development do
  gem 'thin'
  # gem 'rake'
end

group :test do
  gem 'rake'
  gem 'rspec'
  gem 'rspec-core'
end

group :production do
end