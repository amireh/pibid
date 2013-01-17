module Sinatra
  module Courier

    module Helpers
      def dispatch_email_verification(u, &cb)
        dispatch_email(u.email,
          "emails/verification",
          "Please verify your email '#{u.email}'") do |success, msg|
          if success
            u.pending_notices({ type: 'email' })
            @n.update({ dispatched: true })
          end

          cb.call(success, msg) if block_given?
        end
      end

      def dispatch_temp_password(u, &cb)
        dispatch_email(u.email, "emails/temp_password", "Temporary account password") do |success, msg|
          if success
            u.pending_notices({ type: 'password' })
            @n.update({ dispatched: true })
          end

          cb.call(success, msg) if block_given?
        end
      end
    end

    def self.registered(app)
      app.helpers Courier::Helpers
    end
  end

  register Courier

  class Base
    def dispatch_email(addr, tmpl, title, &cb)
      unless settings.courier['enabled']
        # puts ">> Courier service disabled << [testing? #{settings.test?}]"
        if settings.test?
          cb.call(true, 'Courier service is currently turned off.') if block_given?
        else
          cb.call(false, 'Courier service is currently turned off.') if block_given?
        end
        return
      end

      # puts ">> Courier service engaged. Delivering to #{addr}: #{title}"

      sent = true
      error_msg = 'Mail could not be delivered, please try again later.'
      begin
        Pony.mail :to => addr,
                  :from => "noreply@#{AppURL}",
                  :subject => "[#{AppName}] #{title}",
                  :html_body => erb(tmpl.to_sym, layout: "layouts/mail".to_sym)
      rescue Exception => e
        error_msg = "Mail could not be delivered: #{e.message}"
        sent = false
      end

      cb.call(sent, error_msg) if block_given?
    end
  end
end