def on_error
  content_type :json
  status response.status

  { :result => 'error', :message => response.body }.to_json
end

error do on_error end
error 400..502 do
  on_error
end