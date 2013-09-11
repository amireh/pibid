namespace :pibi do
  desc 'creates a demo account'
  task :create_demo_account => :environment do
    puts User.first_or_create({ email: "pibi@algollabs.com" }, {
      name: "Pibi Demo",
      provider: "pibi",
      password: "pibidemo123",
      password_confirmation: "pibidemo123"
    }).errors.empty?
  end
end