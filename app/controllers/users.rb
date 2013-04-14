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


post '/users', auth: :guest, provides: [ :json ] do
  @user = build_user_from_pibi

  unless @user.save
    halt 400, @user.errors
  end

  authorize(@user)

  respond_with @user do |f|
    f.json { rabl :"users/show" }
  end
end

# route_namespace '/users/:user_id' do
  # before do
  #   restrict_to(:user, with: { id: params[:user_id].to_i })
  # end

get '/users/:user_id', auth: :user, requires: [ :user ], :provides => [ :json ] do
  rabl :"users/show"
end

patch '/users/:user_id',
  auth: [ :user ],
  provides: [ :json ],
  requires: [ :user ] do

  api_optional!({
    name: nil,
    gravatar_email: nil,
    email: nil,
    preferences: nil,

    current_password: lambda { |pw|
      pw ||= ''

      if !pw.empty? && User.encrypt(pw) != current_user.password
        return "The current password you entered is wrong."
      end

      true
    },

    password: nil,
    password_confirmation: nil
  })

  api_consume! :preferences do |prefs|
    @user.save_preferences(@user.preferences.deep_merge(prefs))
  end

  api_consume! :current_password

  api_consume! :currency do |currency|
    currency = currency.to_s

    if current_account.currency != currency
      unless current_account.update({ currency: currency })
        halt 400, current_account.errors
      end
    end
  end

  unless @user.update(api_params)
    halt 400, @user.errors
  end

  if params[:no_object]
    halt 200, {}.to_json
  end

  respond_to do |f|
    f.json { rabl :"users/show", object: @user }
  end
end


  # Accepts:
  # => name: String
  # => email: String
  # => gravatar_email: String
  # => password: { :current, :new, :confirmation }
  # => currency: String
  # put '/users/:user_id', auth: :user, requires: [ :user ], :provides => [ :json ] do
  #   updatable_params = accept_params([ :name, :email, :gravatar_email ], @user)

  #   if params.has_key?('password') && params[:password][:current]
  #     if User.encrypt(params[:password][:current]) != @user.password
  #       @user.errors.add(:password, "Invalid current password")
  #       halt 400, @user.report_errors
  #     elsif params[:password][:new].length < 7
  #       @user.errors.add(:password, 'Password is too short! It must be at least 7 characters long.')
  #       halt 400, @user.report_errors
  #     else

  #       if params[:password][:new] != params[:password][:current]
  #         updatable_params[:password]               = User.encrypt(params[:password][:new])
  #         updatable_params[:password_confirmation]  = User.encrypt(params[:password][:confirmation])
  #       end
  #     end
  #   end

  #   unless @user.update(updatable_params)
  #     halt 400, @user.report_errors
  #   end

  #   # the account default currency
  #   if params.has_key?('currency')
  #     if current_account.currency != params[:currency]
  #       unless current_account.update({ currency: params[:currency] })
  #         halt 400, @account.all_errors
  #       end
  #     end
  #   end

  #   # remove the "temp-password" status and notifications (if any)
  #   # if the user has updated their password
  #   if updatable_params.has_key?(:password)
  #     @user.pending_notices({ type: 'password' }).each { |n| n.accept! }
  #   end

  #   status 200
  #   rabl :"users/show"
  # end

  delete '/users/:user_id/links/:provider', auth: :user, requires: [ :user ], provides: [ :json ] do |_,provider|
    unless linked_user = @user.linked_to?(provider)
      halt 400, "That account is not linked to a #{provider_name(provider)} one."
    end

    unless linked_user.detach_from_master
      halt 500, linked_user.errors
    end

    204
  end

# end