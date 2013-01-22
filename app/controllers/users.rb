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
  @user = build_user_from_pibi

  unless @user.save
    halt 400, @user.report_errors
  end

  authorize(@user)

  rabl :"users/show"
end

route_namespace '/users/:user_id' do
  before do
    restrict_to(:user, with: { id: params[:user_id].to_i })
  end

  get :provides => [ :json ] do
    rabl :"users/show"
  end

  # Accepts:
  # => name: String
  # => email: String
  # => gravatar_email: String
  # => password: { :current, :new, :confirmation }
  # => currency: String
  put :provides => [ :json ] do
    updatable_params = accept_params([ :name, :email, :gravatar_email ], @user)

    if params.has_key?('password') && params[:password][:current]
      if User.encrypt(params[:password][:current]) != @user.password
        @user.errors.add(:password, "Invalid current password")
        halt 400, @user.report_errors
      elsif params[:password][:new].length < 7
        @user.errors.add(:password, 'Password is too short! It must be at least 7 characters long.')
        halt 400, @user.report_errors
      else

        if params[:password][:new] != params[:password][:current]
          updatable_params[:password]               = User.encrypt(params[:password][:new])
          updatable_params[:password_confirmation]  = User.encrypt(params[:password][:confirmation])
        end
      end
    end

    unless @user.update(updatable_params)
      halt 400, @user.report_errors
    end

    # the account default currency
    if params.has_key?('currency')
      if current_account.currency != params[:currency]
        unless current_account.update({ currency: params[:currency] })
          halt 400, @account.all_errors
        end
      end
    end

    # remove the "temp-password" status and notifications (if any)
    # if the user has updated their password
    if updatable_params.has_key?(:password)
      @user.pending_notices({ type: 'password' }).each { |n| n.accept! }
    end

    status 200
    rabl :"users/show"
  end

  delete '/links/:provider' do |provider|
    unless linked_user = @user.linked_to?(provider)
      halt 400, "That account is not linked to a #{provider_name(provider)} one."
    end

    unless linked_user.detach_from_master
      halt 500, linked_user.report_errors
    end

    204
  end

end