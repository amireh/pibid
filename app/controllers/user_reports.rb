post '/users/:user_id/reports',
  provides: [ :json ],
  requires: [ :user ],
  auth: [ :user ] do

  api_required!({
    segment: lambda { |v|
      unless v =~ /\d{4}(?:\/\d{1,2})?(?:\/\d{1,2})?/
        return "Segment must be a string date of the format: YYYY/MM/DD"
      end
    }
  })

  comlink.queue 'reports', 'generate', append_user_to_message({
    client_id: @user.id,
    token: session.id,
    segment: api_param(:segment)
  })

  respond_to do |f|
    f.json { '{}' }
  end
end