before do
  content_type :json
end

def on_error
  status response.status

  { :result => 'error', :message => response.body }.to_json
end

error do
  on_error
end

error 400..502 do
  on_error
end

error 404 do
  response.body = "No such resource."
  on_error
end
