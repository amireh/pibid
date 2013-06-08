configure do |app|

  use OmniAuth::Builder do |config|
    OmniAuth.config.on_failure = Proc.new { |env|
      OmniAuth::FailureEndpoint.new(env).redirect_to_failure
    }

    provider :developer unless app.production?

    OmniAuth.config.full_host = app.oauth['host']

    provider :facebook,
      app.oauth['facebook']['key'],
      app.oauth['facebook']['secret']

    provider :google_oauth2,
      app.oauth['google']['key'],
      app.oauth['google']['secret'],
      { access_type: "offline", approval_prompt: "" }

    provider :github,
      app.oauth['github']['key'],
      app.oauth['github']['secret']
  end
end