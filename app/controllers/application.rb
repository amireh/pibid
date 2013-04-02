before do
  content_type :json

  response['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept'
end

# def on_error(msg = response.body)
#   status response.status
#   response['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept'

#   { :result => 'error', :message => msg }.to_json
# end

# error do
#   on_error
# end

# # error 400..502 do
# #   on_error
# # end
# error 400 do on_error end
# error 401 do on_error end
# error 403 do on_error end
# error 404 do on_error "No such resource." end
# error 500 do on_error end
