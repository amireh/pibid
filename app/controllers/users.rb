module Sinatra
  module UsersController
    module Helpers
      def create_user_from_oauth(provider, auth)
        # create the user if it's their first time
        new_user = false
        unless u = User.first({ uid: auth.uid, provider: provider })

          uparams = { uid: auth.uid, provider: provider, name: auth.info.name }
          uparams[:email] = auth.info.email if auth.info.email
          uparams[:oauth_token] = auth.credentials.token if auth.credentials.token
          uparams[:oauth_secret] = auth.credentials.secret if auth.credentials.secret
          uparams[:password] = uparams[:password_confirmation] = User.encrypt(Pibi::salt)
          uparams[:auto_password] = true

          if auth.extra.raw_info then
            uparams[:extra] = auth.extra.raw_info.to_json.to_s
          end

          # puts "Creating a new user from #{provider} with params: \n#{uparams.inspect}"
          new_user = true
          # create the user
          slave = User.create(uparams)

          # create a pibi user and link the provider-specific one to it
          master = build_user_from_pibi(uparams)
          master.save
          slave.link_to(master)

          u = master
        end

        [ u, new_user ]
      end

      def build_user_from_pibi(p = {})
        p = params if p.empty?
        u = User.new(p.merge({
          uid:      UUID.generate,
          provider: "pibi"
        }))

        if u.valid?
          u.password = User.encrypt(p[:password])
          u.password_confirmation = User.encrypt(p[:password_confirmation])
        end

        u
      end
    end # Helpers

    def self.registered(app)
      app.helpers UsersController::Helpers
    end
  end # UsersController

  register UsersController
end # Sinatra


post '/users', auth: :guest do
  u = build_user_from_pibi
  if !u.valid? || !u.save || !u.saved?
    flash[:error] = u.all_errors
    return redirect '/users/new'
  end

  flash[:notice] = "Welcome to #{AppName}! Your new personal account has been registered."

  authorize(u)

  redirect '/'
end

delete '/users/links/:provider', auth: :user do |provider|

  if u = current_user.linked_to?(provider)
    if u.detach_from_master
      flash[:notice] = "Your current account is no longer linked to the #{provider_name(provider)} one" +
                       " with the email '#{u.email}'."
    else
      flash[:error] = "Unable to unlink accounts: #{u.all_errors}"
    end
  else
    flash[:error] = "Your current account is not linked to a #{provider_name(provider)} one!"
  end

  redirect '/settings/account'
end