before do
  content_type :json unless request.request_method == 'OPTIONS'
end

options '*' do
  response['Access-Control-Max-Age'] = '1728000'

  halt 200
end

get '/preferences', :provides => [ :json ] do
  respond_to do |f|
    f.json do
      Pibi::Preferences.defaults['app'].to_json
    end
  end
end

def blank_halt!(rc = 200)
  halt 200, '{}'
end