configure do |app|
  use OmniAuth::Builder do |config|
    OmniAuth.config.on_failure = Proc.new { |env|
      OmniAuth::FailureEndpoint.new(env).redirect_to_failure
    }

    provider :developer

    unless app.settings.test?
      provider :facebook,
        app.settings.credentials['facebook'][app.settings.environment.to_s]['key'],
        app.settings.credentials['facebook'][app.settings.environment.to_s]['secret']

      provider :google_oauth2,
        app.settings.credentials['google']['key'],
        app.settings.credentials['google']['secret'],
        { access_type: "offline", approval_prompt: "" }

      provider :github,
        app.settings.credentials['github'][app.settings.environment.to_s]['key'],
        app.settings.credentials['github'][app.settings.environment.to_s]['secret']
    end
  end
end