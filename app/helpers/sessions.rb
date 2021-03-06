module Sinatra
  module SessionsHelper
    def logged_in?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)

      if @auth.provided? && @auth.basic? && @auth.credentials
        if u = authenticate(@auth.credentials.first, @auth.credentials.last)
          authorize(u)
        end
      elsif digest = request.env['HTTP_X_ACCESS_TOKEN']
        unless @access_token = AccessToken.first({ digest: digest })
          halt 401
        end

        authorize(@access_token.user)
      end

      !current_user.nil?
    end

    def restricted!(scope = nil)
      halt 401, "You must sign in first" unless logged_in?
    end

    def restrict_to(roles, options = {})
      roles = [ roles ] if roles.is_a? Symbol

      if logged_in?
        if roles.include?(:guest)
          halt 403, 'Already logged in.'
        end

        return true
      end

      restricted! if roles.include?(:user)
    end

    def current_user
      if @current_user
        return @current_user
      end

      unless session[:id]
        return nil
      end

      @current_user = User.get(session[:id])
    end

    def current_account
      # unless session[:account]
      #   session[:account] = current_user.accounts.first.id
      # end

      @current_account ||= current_user.accounts.first
    end

    def authenticate(email, pw, encrypt = true)
      User.first({
        email:    email,
        password: encrypt ? User.encrypt(pw) : pw,
        provider: 'pibi'
      })
    end

    def authorize(user)
      # puts "logging in #{user.email}"
      if user.link
        # reset the state vars
        @user = nil
        @account = nil

        # mark the master account as the current user
        session[:id] = user.link.id

        # refresh the state vars
        @user     = current_user
        @account  = current_account
      else
        session[:id] = user.id
      end
    end

  end

  helpers SessionsHelper
  helpers do
    set(:auth) do |*roles|
      condition do
        restrict_to(roles)
      end
    end
  end
end