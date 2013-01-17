def on_error
  content_type :json
  status response.status

  { :result => 'error', :message => response.body }.to_json
end

error do on_error end