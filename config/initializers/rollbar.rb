set :show_exceptions, :after_handler

configure do
	puts '>> Configuring Rollbar'
	Rollbar.configure do |config|
		config.access_token = '0726b3d86a6d41d7b8d9d2bdd1bf1e06'
		config.environment = Sinatra::Base.environment
		config.root = Dir.pwd
	end
end