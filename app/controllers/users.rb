class SlaveCreationError < RuntimeError;  end
class MasterCreationError < RuntimeError; end
class LinkingError < RuntimeError;        end

module Sinatra
  module UsersController
    module Helpers

      def oauth_to_user_hash(provider, auth)
        some_salt = tiny_salt

        {
          provider: provider,
          uid:      auth.uid,
          name:     auth.info.name,
          email:    auth.email || auth.info.email || '',
          password: some_salt,
          password_confirmation: some_salt,
          auto_password: true,
          oauth_token:  auth.credentials && auth.credentials.token,
          oauth_secret: auth.credentials && auth.credentials.secret,
          extra:        (auth.extra && auth.extra.raw_info || '{}').to_json.to_s
        }
      end

      def user_from_oauth(provider, auth)
        new_user, slave, user_info = false, nil, {}

        # puts provider
        # puts auth.inspect

        # create the user if it's their first time
        unless slave = User.first({ uid: auth.uid, provider: provider })
          new_user = true
          user_info = oauth_to_user_hash(provider, auth)

          slave = User.create(user_info)

          unless slave.saved?
            raise SlaveCreationError, slave.errors.to_json
          end
        end

        master = nil

        # Create a Pibi user and use it as a master if the user isn't authenticated
        # (ie, isn't linking a 3rd-party account)
        if new_user && !logged_in?
          master = build_user_from_pibi(user_info)

          # Can't create a master account? perhaps the email is already registered,
          # in this case we can do one of two things:
          #
          #   1. accept the 3rd-party account as a master but then the user will not
          #      be able to authenticate manually as that's exclusive to Pibi users
          #   2. reject the sign-up entirely
          #
          # For now, we will opt for #1
          if !master.save
            return slave
            # raise MasterCreationError, master.errors
            # return [ nil, master.errors ]
          end

          unless slave.link_to(master)
            raise LinkingError, slave.errors.to_json
          end
        # A returning user authenticating using a 3rd-party account
        elsif !new_user && !logged_in?
          master = slave.link
        elsif logged_in?
          # Linking a 3rd-party account, current_user is the master in this case
          master = current_user

          unless slave.link_to(master)
            raise LinkingError, slave.errors.to_json
          end
        end

        master
      end

      def build_user_from_pibi(p = {})
        p = params if p.empty?
        u = User.new(p.merge({
          uid:      UUID.generate,
          provider: "pibi"
        }))

        if u.valid?
          u.password = p[:password]
          u.password_confirmation = p[:password_confirmation]
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

helpers do
  def user_users_update(user, p = params)
    user = current_user

    api_optional!({
      name: nil,
      gravatar_email: nil,
      email: nil,
      preferences: nil,

      current_password: lambda { |pw|
        pw = (pw||'').to_s

        if !pw.empty? && User.encrypt(pw) != current_user.password
          return "The current password you entered is wrong."
        end

        true
      },

      password: nil,
      password_confirmation: nil,
      preferences: nil
    }, p)

    api_consume! :preferences do |prefs|
      user.update_preferences(prefs)
    end

    api_consume! :current_password

    unless user.update(api_params)
      halt 400, user.errors
    end

    user
  end
end

post '/users', auth: :guest, provides: [ :json ] do
  api_required!({
    name: nil,
    email: nil,
    password: nil,
    password_confirmation: nil
  })

  @user = build_user_from_pibi(api_params)

  unless @user.save
    halt 400, @user.errors
  end

  authorize(@user)

  respond_with @user do |f|
    f.json { rabl :"users/show" }
  end
end

get '/users/:user_id', auth: :user, requires: [ :user ], :provides => [ :json ] do
  respond_with @user do |f|
    f.json { rabl :"users/show" }
  end
end

patch '/users/:user_id',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user ] do

  user_users_update(current_user)

  blank_halt! 204 if params[:no_object]

  respond_with @user do |f|
    f.json { rabl :"users/show" }
  end
end

delete '/users/:user_id/links/:provider', auth: :user, requires: [ :user ], provides: [ :json ] do |_,provider|
  unless linked_user = @user.linked_to?(provider)
    halt 400, "That account is not linked to a #{provider_name(provider)} one."
  end

  unless linked_user.detach_from_master
    halt 500, linked_user.errors
  end

  blank_halt! 205
end

delete '/users/:user_id',
  auth: :user,
  requires: [ :user ],
  provides: [ :json ] do

  unless @user.destroy
    halt 400, @user.errors
  end

  session[:id] = nil

  halt 200, '{}'
end