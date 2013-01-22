before do
  content_type :json
end

def on_error(msg = response.body)
  status response.status

  { :result => 'error', :message => msg }.to_json
end

error do
  on_error
end

# error 400..502 do
#   on_error
# end

error 404 do on_error "No such resource." end
error 500 do on_error "Internal Server Error." end
