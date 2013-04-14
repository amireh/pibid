before do
  content_type :json unless request.request_method == 'OPTIONS'

  # response['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept'
  # response['Access-Control-Allow-Headers'] = 'origin, x-requested-with, content-type, accept'
end

options '*' do
  response['Access-Control-Allow-Headers'] = 'origin, x-requested-with, content-type, accept'
  halt 200
end

def blank_halt!(rc = 200)
  halt 200, '{}'
end